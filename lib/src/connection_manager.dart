import 'dart:async';
import 'dart:convert';
import 'package:livekit_client/livekit_client.dart';
import 'package:http/http.dart' as http;
import 'models/avatar_state.dart';
import 'utils/logger.dart';

class ConnectionManager {
  Room? _room;
  EventsListener<RoomEvent>? _listener;
  RemoteParticipant? _avatarParticipant;
  RemoteVideoTrack? _avatarVideoTrack;
  RemoteAudioTrack? _avatarAudioTrack;
  
  final String tokenUrl;
  final String? livekitUrl;
  final String roomName;
  final String userIdentity;
  final Duration connectionTimeout;
  
  final void Function(AvatarState state)? onStateChanged;
  final void Function(RemoteVideoTrack? track)? onAvatarVideoTrack;
  final void Function(String event, Map<String, dynamic> data)? onEvent;

  ConnectionManager({
    required this.tokenUrl,
    this.livekitUrl,
    required this.roomName,
    required this.userIdentity,
    required this.connectionTimeout,
    this.onStateChanged,
    this.onAvatarVideoTrack,
    this.onEvent,
  });

  Future<Map<String, String>> _getConnectionToken() async {
    TavusLogger.info('Fetching connection token from: $tokenUrl');
    
    try {
      final uri = Uri.parse(tokenUrl).replace(queryParameters: {
        'identity': userIdentity,
        'room': roomName,
      });
      
      final response = await http.get(uri).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw TimeoutException('Token request timed out'),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        TavusLogger.info('Successfully obtained connection token');
        
        return {
          'token': data['accessToken'] ?? data['token'] ?? '',
          'url': data['url'] ?? livekitUrl ?? 'wss://cloud.livekit.io',
        };
      } else {
        throw Exception('Token server returned ${response.statusCode}: ${response.body}');
      }
    } catch (e, stackTrace) {
      TavusLogger.error('Failed to get connection token', e, stackTrace);
      rethrow;
    }
  }

  Future<void> connect() async {
    TavusLogger.info('Starting Tavus avatar connection');
    _notifyState(AvatarState.connecting);
    
    try {
      // Get connection token
      final connectionInfo = await _getConnectionToken();
      final token = connectionInfo['token']!;
      final url = connectionInfo['url']!;
      
      TavusLogger.info('Connecting to LiveKit room at: $url');
      
      // Create room
      _room = Room();
      
      // Set up event listeners before connecting
      _setupEventListeners();
      
      // Configure room options
      const roomOptions = RoomOptions(
        adaptiveStream: true,
        dynacast: true,
        defaultAudioCaptureOptions: AudioCaptureOptions(
          echoCancellation: true,
          noiseSuppression: true,
          autoGainControl: true,
        ),
        defaultAudioPublishOptions: AudioPublishOptions(
          dtx: true,
          red: true//,
          // audioBitrate: AudioBitrate.unset,
        ),
      );
      
      // Connect to room
      await _room!.connect(
        url, 
        token, 
        roomOptions: roomOptions,
      ).timeout(
        connectionTimeout,
        onTimeout: () => throw TimeoutException('Connection timed out'),
      );
      
      TavusLogger.info('Successfully connected to LiveKit room');
      TavusLogger.info('Room name: ${_room!.name}');
      TavusLogger.info('Local participant: ${_room!.localParticipant?.identity}');
      
      // Enable microphone for voice interaction
      await _room!.localParticipant?.setMicrophoneEnabled(true);
      TavusLogger.info('Microphone enabled for voice interaction');
      
      // Check for existing avatar participant
      _checkForAvatarParticipant();
      
    } catch (e, stackTrace) {
      TavusLogger.error('Connection failed', e, stackTrace);
      _notifyState(AvatarState.error);
      rethrow;
    }
  }

  void _setupEventListeners() {
    if (_room == null) return;
    
    _listener = _room!.createListener();
    
    TavusLogger.info('Setting up avatar event listeners');
    
    _listener!
      ..on<ParticipantConnectedEvent>((event) {
        TavusLogger.info('Participant connected: ${event.participant.identity}');
        
        // Check if this is the avatar agent
        if (_isAvatarParticipant(event.participant)) {
          _handleAvatarConnected(event.participant as RemoteParticipant);
        }
        
        _notifyEvent('participant_connected', {
          'identity': event.participant.identity,
          'sid': event.participant.sid,
          'isAvatar': _isAvatarParticipant(event.participant),
        });
      })
      ..on<ParticipantDisconnectedEvent>((event) {
        TavusLogger.info('Participant disconnected: ${event.participant.identity}');
        
        if (event.participant == _avatarParticipant) {
          _handleAvatarDisconnected();
        }
        
        _notifyEvent('participant_disconnected', {
          'identity': event.participant.identity,
        });
      })
      ..on<TrackSubscribedEvent>((event) {
        TavusLogger.info('Track subscribed: ${event.track.kind} from ${event.participant.identity}');
        
        if (event.participant == _avatarParticipant) {
          _handleAvatarTrackSubscribed(event.track);
        }
      })
      ..on<TrackUnsubscribedEvent>((event) {
        TavusLogger.info('Track unsubscribed: ${event.track.kind} from ${event.participant.identity}');
        
        if (event.participant == _avatarParticipant && event.track == _avatarVideoTrack) {
          _avatarVideoTrack = null;
          onAvatarVideoTrack?.call(null);
        }
      })
      ..on<RoomDisconnectedEvent>((event) {
        TavusLogger.warning('Room disconnected: ${event.reason}');
        _notifyState(AvatarState.disconnected);
        _cleanup();
      })
      ..on<RoomReconnectingEvent>((event) {
        TavusLogger.info('Room reconnecting...');
        _notifyState(AvatarState.reconnecting);
      })
      ..on<RoomReconnectedEvent>((event) {
        TavusLogger.info('Room reconnected');
        _checkForAvatarParticipant();
      });
  }

  bool _isAvatarParticipant(Participant participant) {
    // Tavus avatars typically have specific identities
    final identity = participant.identity?.toLowerCase() ?? '';
    return identity.contains('tavus') || 
           identity.contains('avatar') || 
           identity.contains('agent');
  }

  void _checkForAvatarParticipant() {
    // Check if avatar is already in the room
    for (final participant in _room!.remoteParticipants.values) {
      if (_isAvatarParticipant(participant)) {
        _handleAvatarConnected(participant);
        break;
      }
    }
  }

  void _handleAvatarConnected(RemoteParticipant participant) {
    TavusLogger.info('Avatar agent connected: ${participant.identity}');
    _avatarParticipant = participant;
    
    // Check for existing tracks
    for (final trackPublication in participant.videoTrackPublications) {
      if (trackPublication.subscribed && trackPublication.track != null) {
        _handleAvatarTrackSubscribed(trackPublication.track!);
      }
    }
    
    _notifyState(AvatarState.connected);
  }

  void _handleAvatarDisconnected() {
    TavusLogger.info('Avatar agent disconnected');
    _avatarParticipant = null;
    _avatarVideoTrack = null;
    _avatarAudioTrack = null;
    onAvatarVideoTrack?.call(null);
    _notifyState(AvatarState.disconnected);
  }

  void _handleAvatarTrackSubscribed(Track track) {
    if (track is RemoteVideoTrack) {
      TavusLogger.info('Avatar video track subscribed');
      _avatarVideoTrack = track;
      onAvatarVideoTrack?.call(track);
    } else if (track is RemoteAudioTrack) {
      TavusLogger.info('Avatar audio track subscribed');
      _avatarAudioTrack = track;
    }
  }

  Future<void> disconnect() async {
    TavusLogger.info('Disconnecting from avatar session');
    
    try {
      await _room?.localParticipant?.setMicrophoneEnabled(false);
      await _room?.disconnect();
      _cleanup();
      _notifyState(AvatarState.disconnected);
    } catch (e) {
      TavusLogger.error('Error during disconnect', e);
    }
  }

  void _cleanup() {
    _listener?.dispose();
    _room?.dispose();
    _room = null;
    _listener = null;
    _avatarParticipant = null;
    _avatarVideoTrack = null;
    _avatarAudioTrack = null;
  }

  bool get isConnected => _room != null && _room!.connectionState == ConnectionState.connected;
  bool get hasAvatar => _avatarParticipant != null && _avatarVideoTrack != null;
  RemoteVideoTrack? get avatarVideoTrack => _avatarVideoTrack;

  void _notifyState(AvatarState state) {
    TavusLogger.debug('Avatar state changed: $state');
    onStateChanged?.call(state);
  }

  void _notifyEvent(String event, Map<String, dynamic> data) {
    onEvent?.call(event, data);
  }

  void dispose() {
    disconnect();
  }
}