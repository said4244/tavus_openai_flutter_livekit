// lib/src/models/avatar_config.dart

/// Configuration for Tavus Avatar
class TavusAvatarConfig {
  /// URL of the token server endpoint
  final String tokenUrl;
  
  /// Optional custom LiveKit server URL
  final String? livekitUrl;
  
  /// Room name to join (defaults to 'tavus-avatar-room')
  final String roomName;
  
  /// User identity for the connection
  final String userIdentity;
  
  /// Enable debug logging
  final bool enableLogging;
  
  /// Connection timeout duration
  final Duration connectionTimeout;
  
  /// Optional avatar customization
  final Map<String, dynamic>? avatarProperties;

  const TavusAvatarConfig({
    required this.tokenUrl,
    this.livekitUrl,
    this.roomName = '',
    this.userIdentity = '',
    this.enableLogging = true,
    this.connectionTimeout = const Duration(seconds: 30),
    this.avatarProperties,
  });
}