import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'tavus_avatar_service.dart';
import 'models/avatar_state.dart';

/// Widget for displaying the Tavus avatar video
class TavusAvatarView extends StatelessWidget {
  /// The avatar instance to display
  final TavusAvatar avatar;
  
  /// Aspect ratio of the video display (default: 9:16 portrait)
  final double aspectRatio;
  
  /// Border radius for the video container
  final BorderRadius? borderRadius;
  
  /// Custom placeholder widget when video is not available
  final Widget? placeholder;
  
  /// Whether to show a loading indicator when connecting
  final bool showLoadingIndicator;
  
  /// Whether to show status messages
  final bool showStatus;
  
  /// Background color when video is not available
  final Color backgroundColor;
  
  /// Custom error widget
  final Widget Function(String error)? errorBuilder;
  
  /// Video fit mode
  final RTCVideoViewObjectFit videoFit;

  const TavusAvatarView({
    Key? key,
    required this.avatar,
    this.aspectRatio = 9 / 16,
    this.borderRadius,
    this.placeholder,
    this.showLoadingIndicator = true,
    this.showStatus = true,
    this.backgroundColor = Colors.black,
    this.errorBuilder,
    this.videoFit = RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: borderRadius ?? BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: borderRadius ?? BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Video or placeholder
              StreamBuilder<RemoteVideoTrack?>(
                stream: avatar.videoTrackStream,
                builder: (context, snapshot) {
                  final videoTrack = snapshot.data;
                  
                  if (videoTrack != null) {
                    return VideoTrackRenderer(
                      videoTrack,
                      fit: videoFit,
                    );
                  }
                  
                  // Show placeholder when no video
                  return _buildPlaceholder(context);
                },
              ),
              
              // Status overlay
              if (showStatus)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: _buildStatusOverlay(context),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder(BuildContext context) {
    return StreamBuilder<AvatarState>(
      stream: avatar.stateStream,
      initialData: avatar.state,
      builder: (context, snapshot) {
        final state = snapshot.data!;
        
        if (state == AvatarState.error && errorBuilder != null) {
          return errorBuilder!(avatar.status);
        }
        
        if (placeholder != null) {
          return placeholder!;
        }
        
        // Default placeholder
        return Container(
          color: backgroundColor,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (state == AvatarState.connecting && showLoadingIndicator)
                  const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  )
                else
                  Icon(
                    _getIconForState(state),
                    size: 64,
                    color: Colors.white.withOpacity(0.5),
                  ),
                const SizedBox(height: 16),
                Text(
                  _getTextForState(state),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (state == AvatarState.error)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      avatar.status,
                      style: TextStyle(
                        color: Colors.red.shade300,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusOverlay(BuildContext context) {
    return StreamBuilder<String>(
      stream: avatar.statusStream,
      initialData: avatar.status,
      builder: (context, snapshot) {
        final status = snapshot.data ?? '';
        if (status.isEmpty || avatar.hasVideo) return const SizedBox.shrink();
        
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.black.withOpacity(0.7),
              ],
            ),
          ),
          child: Text(
            status,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        );
      },
    );
  }

  IconData _getIconForState(AvatarState state) {
    switch (state) {
      case AvatarState.connecting:
      case AvatarState.reconnecting:
        return Icons.sync;
      case AvatarState.connected:
        return Icons.person;
      case AvatarState.error:
        return Icons.error_outline;
      case AvatarState.disconnected:
      default:
        return Icons.videocam_off;
    }
  }

  String _getTextForState(AvatarState state) {
    switch (state) {
      case AvatarState.connecting:
        return 'Connecting to avatar...';
      case AvatarState.reconnecting:
        return 'Reconnecting...';
      case AvatarState.connected:
        return 'Avatar connected';
      case AvatarState.error:
        return 'Connection error';
      case AvatarState.disconnected:
      default:
        return 'Tap to start';
    }
  }
}