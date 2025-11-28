import 'package:flutter/material.dart';
import 'package:tavus_avatar_flutter/tavus_avatar_flutter.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tavus Avatar Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const AvatarDemo(),
    );
  }
}

class AvatarDemo extends StatefulWidget {
  const AvatarDemo({super.key});

  @override
  State<AvatarDemo> createState() => _AvatarDemoState();
}

class _AvatarDemoState extends State<AvatarDemo> with SingleTickerProviderStateMixin {
  late final TavusAvatar avatar;
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    
    // Initialize avatar - that's all the configuration needed!
    avatar = TavusAvatar(
      config: TavusAvatarConfig(
        tokenUrl: 'http://localhost:8080/token',
        roomName: 'tavus-avatar-livekit-room',
        enableLogging: true,
      ),
    );
    
    // Pulse animation for the button
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    // Listen to avatar state changes
    avatar.stateStream.listen((state) {
      if (state == AvatarState.connected) {
        _pulseController.repeat(reverse: true);
      } else {
        _pulseController.stop();
        _pulseController.reset();
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    avatar.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E27),
      body: SafeArea(
        child: Column(
          children: [
            // App Header
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  const Icon(
                    Icons.smart_toy,
                    color: Colors.white,
                    size: 32,
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Tavus AI Avatar',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  // Connection indicator
                  StreamBuilder<AvatarState>(
                    stream: avatar.stateStream,
                    initialData: avatar.state,
                    builder: (context, snapshot) {
                      final state = snapshot.data!;
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _getStateColor(state).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _getStateColor(state),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: _getStateColor(state),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _getStateText(state),
                              style: TextStyle(
                                color: _getStateColor(state),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            
            // Avatar video display
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: TavusAvatarView(
                      avatar: avatar,
                      aspectRatio: 9 / 16,  // Portrait orientation
                      borderRadius: BorderRadius.circular(24),
                      showStatus: false,  // We show custom status above
                      placeholder: _buildCustomPlaceholder(),
                    ),
                  ),
                ),
              ),
            ),
            
            // Control section
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  // Status text
                  StreamBuilder<String>(
                    stream: avatar.statusStream,
                    initialData: avatar.status,
                    builder: (context, snapshot) {
                      return Text(
                        snapshot.data ?? '',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  
                  // Main toggle button
                  StreamBuilder<AvatarState>(
                    stream: avatar.stateStream,
                    initialData: avatar.state,
                    builder: (context, snapshot) {
                      final state = snapshot.data!;
                      final isActive = state == AvatarState.connected || 
                                       state == AvatarState.connecting;
                      
                      return GestureDetector(
                        onTap: () => avatar.toggle(),
                        child: AnimatedBuilder(
                          animation: _pulseAnimation,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: isActive ? _pulseAnimation.value : 1.0,
                              child: Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: isActive
                                        ? [Colors.red.shade400, Colors.red.shade700]
                                        : [Colors.green.shade400, Colors.green.shade700],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: (isActive ? Colors.red : Colors.green)
                                          .withOpacity(0.5),
                                      blurRadius: isActive ? 40 : 20,
                                      spreadRadius: isActive ? 5 : 2,
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  isActive ? Icons.stop : Icons.play_arrow,
                                  size: 50,
                                  color: Colors.white,
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                  
                  const SizedBox(height: 16),
                  
                  Text(
                    'Tap to ${avatar.isConnected ? 'stop' : 'start'} conversation',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.deepPurple.shade900,
            Colors.purple.shade800,
          ],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.account_circle,
            size: 100,
            color: Colors.white.withOpacity(0.2),
          ),
          const SizedBox(height: 24),
          Text(
            'AI Avatar',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 24,
              fontWeight: FontWeight.w300,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ready to chat',
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStateColor(AvatarState state) {
    switch (state) {
      case AvatarState.connected:
        return Colors.green;
      case AvatarState.connecting:
      case AvatarState.reconnecting:
        return Colors.orange;
      case AvatarState.error:
        return Colors.red;
      case AvatarState.disconnected:
      default:
        return Colors.grey;
    }
  }

  String _getStateText(AvatarState state) {
    switch (state) {
      case AvatarState.connected:
        return 'Connected';
      case AvatarState.connecting:
        return 'Connecting';
      case AvatarState.reconnecting:
        return 'Reconnecting';
      case AvatarState.error:
        return 'Error';
      case AvatarState.disconnected:
      default:
        return 'Offline';
    }
  }
}