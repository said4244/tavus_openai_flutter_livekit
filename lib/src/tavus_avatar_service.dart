import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';
import 'connection_manager.dart';
import 'models/avatar_config.dart';
import 'models/avatar_state.dart';
import 'utils/logger.dart';

/// Main service class for Tavus Avatar integration
class TavusAvatar {
  final TavusAvatarConfig config;
  late final ConnectionManager _connectionManager;
  
  AvatarState _state = AvatarState.disconnected;
  RemoteVideoTrack? _avatarVideoTrack;
  String _statusMessage = 'Disconnected';
  Map<String, dynamic> _lastEvent = {};
  
  final _stateController = StreamController<AvatarState>.broadcast();
  final _videoTrackController = StreamController<RemoteVideoTrack?>.broadcast();
  final _statusController = StreamController<String>.broadcast();
  final _eventController = StreamController<Map<String, dynamic>>.broadcast();

  TavusAvatar({required this.config}) {
    TavusLogger.setEnabled(config.enableLogging);
    TavusLogger.info('Initializing Tavus Avatar');
    TavusLogger.info('Token URL: ${config.tokenUrl}');
    TavusLogger.info('Room: ${config.roomName}');
    TavusLogger.info('Platform: ${kIsWeb ? "Web" : "Native"}');
    
    _connectionManager = ConnectionManager(
      tokenUrl: config.tokenUrl,
      livekitUrl: config.livekitUrl,
      roomName: config.roomName,
      userIdentity: config.userIdentity,
      connectionTimeout: config.connectionTimeout,
      onAvatarVideoTrack: _handleVideoTrack,
      onStateChanged: _handleStateChange,
      onEvent: _handleEvent,
    );
  }

  /// Simple toggle method - starts if stopped, stops if started
  Future<void> toggle() async {
    if (_state == AvatarState.disconnected || _state == AvatarState.error) {
      await start();
    } else {
      await stop();
    }
  }

  /// Start the avatar session
  Future<void> start() async {
    if (_state == AvatarState.connected || _state == AvatarState.connecting) {
      TavusLogger.warning('Avatar already connected or connecting');
      return;
    }

    TavusLogger.info('Starting Tavus avatar session');
    _updateState(AvatarState.connecting);
    _updateStatus('Connecting to avatar...');

    try {
      await _connectionManager.connect();
      
      // Wait a moment for avatar to join
      await Future.delayed(const Duration(seconds: 2));
      
      if (_connectionManager.hasAvatar) {
        _updateStatus('Avatar ready! Say hello!');
      } else {
        _updateStatus('Connected - Waiting for avatar...');
      }
      
      TavusLogger.info('Avatar session started successfully');
    } catch (e) {
      TavusLogger.error('Failed to start avatar session', e);
      _updateState(AvatarState.error);
      _updateStatus('Error: ${e.toString()}');
      rethrow;
    }
  }

  /// Stop the avatar session
  Future<void> stop() async {
    if (_state == AvatarState.disconnected) {
      TavusLogger.warning('Avatar already disconnected');
      return;
    }

    TavusLogger.info('Stopping avatar session');
    _updateStatus('Disconnecting...');
    
    try {
      await _connectionManager.disconnect();
      _avatarVideoTrack = null;
      _videoTrackController.add(null);
      _updateState(AvatarState.disconnected);
      _updateStatus('Disconnected');
      TavusLogger.info('Avatar session stopped');
    } catch (e) {
      TavusLogger.error('Error stopping avatar session', e);
    }
  }

  /// Send a custom message to the avatar (if supported by your agent)
  Future<void> sendMessage(String message) async {
    if (!isConnected) {
      throw Exception('Avatar not connected');
    }
    
    // This would require custom implementation in your agent
    // For now, it's a placeholder for future functionality
    TavusLogger.info('Custom messaging not yet implemented');
    _handleEvent('custom_message_sent', {'message': message});
  }

  /// Dispose of resources
  void dispose() {
    TavusLogger.info('Disposing Tavus avatar');
    stop();
    _stateController.close();
    _videoTrackController.close();
    _statusController.close();
    _eventController.close();
    _connectionManager.dispose();
  }

  // Getters
  /// Current connection state
  AvatarState get state => _state;
  
  /// Whether the avatar is connected and ready
  bool get isConnected => _state == AvatarState.connected;
  
  /// Whether the avatar video is available
  bool get hasVideo => _avatarVideoTrack != null;
  
  /// Current status message
  String get status => _statusMessage;
  
  /// Last event data
  Map<String, dynamic> get lastEvent => _lastEvent;
  
  /// Current avatar video track (if available)
  RemoteVideoTrack? get videoTrack => _avatarVideoTrack;

  // Streams
  /// Stream of connection state changes
  Stream<AvatarState> get stateStream => _stateController.stream;
  
  /// Stream of avatar video track changes
  Stream<RemoteVideoTrack?> get videoTrackStream => _videoTrackController.stream;
  
  /// Stream of status message updates
  Stream<String> get statusStream => _statusController.stream;
  
  /// Stream of all events
  Stream<Map<String, dynamic>> get eventStream => _eventController.stream;

  // Private methods
  void _updateState(AvatarState newState) {
    _state = newState;
    _stateController.add(newState);
    TavusLogger.debug('State updated: $newState');
  }

  void _updateStatus(String status) {
    _statusMessage = status;
    _statusController.add(status);
  }

  void _handleVideoTrack(RemoteVideoTrack? track) {
    _avatarVideoTrack = track;
    _videoTrackController.add(track);
    
    if (track != null) {
      _updateStatus('Avatar video active');
      TavusLogger.info('Avatar video track received');
    } else {
      TavusLogger.info('Avatar video track removed');
    }
  }

  void _handleStateChange(AvatarState state) {
    _updateState(state);
    
    // Update status message based on state
    switch (state) {
      case AvatarState.connecting:
        _updateStatus('Connecting...');
        break;
      case AvatarState.connected:
        _updateStatus('Connected - Avatar active!');
        break;
      case AvatarState.reconnecting:
        _updateStatus('Connection lost - Reconnecting...');
        break;
      case AvatarState.disconnected:
        _updateStatus('Disconnected');
        break;
      case AvatarState.error:
        // Status already set with error message
        break;
    }
  }

  void _handleEvent(String event, Map<String, dynamic> data) {
    _lastEvent = {
      'type': event,
      'data': data,
      'timestamp': DateTime.now().toIso8601String(),
    };
    _eventController.add(_lastEvent);
    
    // Log important events
    if (event == 'participant_connected' && data['isAvatar'] == true) {
      _updateStatus('Avatar joined the session!');
    }
  }
}