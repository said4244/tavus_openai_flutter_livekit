/// Connection state of the avatar
enum AvatarState {
  /// Not connected to any room
  disconnected,
  
  /// Attempting to connect
  connecting,
  
  /// Successfully connected and avatar is active
  connected,
  
  /// Connection error occurred
  error,
  
  /// Connection lost, attempting to reconnect
  reconnecting,
}