import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/auth_wrapper.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _textController;
  late AnimationController _backgroundController;
  late Animation<double> _logoAnimation;
  late Animation<double> _textAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _backgroundAnimation;
  late Animation<double> _pulseAnimation;
  
  String _statusMessage = "Initializing SwimSight...";

  @override
  void initState() {
    super.initState();
    
    // Setup animations
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    );
    _textController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _backgroundController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    );
    
    _logoAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _logoController,
      curve: Curves.elasticOut,
    ));
    
    _scaleAnimation = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _logoController,
      curve: Curves.bounceOut,
    ));
    
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _logoController,
      curve: Curves.easeInOut,
    ));
    
    _textAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _textController,
      curve: Curves.easeInOut,
    ));
    
    _backgroundAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _backgroundController,
      curve: Curves.easeInOut,
    ));
    
    _initializeApp();
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    _backgroundController.dispose();
    super.dispose();
  }

  Future<void> _initializeApp() async {
    try {
      // Start background animation
      _backgroundController.forward();
      
      // Start logo animation
      _logoController.forward();
      
      setState(() {
        _statusMessage = "🔥 Connecting to Firebase...";
      });
      
      await Future.delayed(const Duration(milliseconds: 1000));
      
      // Start text animation
      _textController.forward();
      
      setState(() {
        _statusMessage = "✅ Firebase connected successfully!";
      });
      
      await Future.delayed(const Duration(milliseconds: 800));
      
      setState(() {
        _statusMessage = "🔐 Checking authentication...";
      });
      
      await Future.delayed(const Duration(milliseconds: 800));
      
      // Check if user is already logged in
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        setState(() {
          _statusMessage = "👋 Welcome back, ${user.displayName ?? 'Swimmer'}!";
        });
        await Future.delayed(const Duration(milliseconds: 1200));
      } else {
        setState(() {
          _statusMessage = "🏊‍♂️ Ready to dive in!";
        });
        await Future.delayed(const Duration(milliseconds: 1000));
      }
      
      // Navigate to AuthWrapper
      if (mounted) {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => const AuthWrapper(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(
                opacity: animation,
                child: child,
              );
            },
            transitionDuration: const Duration(milliseconds: 800),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _statusMessage = "❌ Initialization failed: $e";
      });
      
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const AuthWrapper()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final logoSize = screenSize.width * 0.6; // 60% of screen width
    
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1E3C72),
              Color(0xFF2A5298),
              Color(0xFF667eea),
              Color(0xFF764ba2),
            ],
          ),
        ),
        child: Stack(
          children: [
            // Animated Background Circles
            AnimatedBuilder(
              animation: _backgroundAnimation,
              builder: (context, child) {
                return Positioned(
                  top: -100,
                  right: -100,
                  child: Opacity(
                    opacity: _backgroundAnimation.value * 0.1,
                    child: Container(
                      width: 300,
                      height: 300,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                );
              },
            ),
            AnimatedBuilder(
              animation: _backgroundAnimation,
              builder: (context, child) {
                return Positioned(
                  bottom: -150,
                  left: -150,
                  child: Opacity(
                    opacity: _backgroundAnimation.value * 0.08,
                    child: Container(
                      width: 400,
                      height: 400,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                );
              },
            ),
            
            // Main Content
            SafeArea(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Spacer(flex: 2),
                    
                    // Full-Screen Logo
                    AnimatedBuilder(
                      animation: _logoController,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _scaleAnimation.value * _pulseAnimation.value,
                          child: Opacity(
                            opacity: _logoAnimation.value,
                            child: Container(
                              width: logoSize,
                              height: logoSize,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.3),
                                    blurRadius: 30,
                                    offset: const Offset(0, 15),
                                    spreadRadius: 5,
                                  ),
                                  BoxShadow(
                                    color: Colors.white.withOpacity(0.1),
                                    blurRadius: 30,
                                    offset: const Offset(0, -10),
                                    spreadRadius: 2,
                                  ),
                                  // Glow effect
                                  BoxShadow(
                                    color: const Color(0xFF2A5298).withOpacity(0.4),
                                    blurRadius: 40,
                                    spreadRadius: 10,
                                  ),
                                ],
                              ),
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.3),
                                    width: 3,
                                  ),
                                ),
                                child: ClipOval(
                                  child: Image.asset(
                                    'assets/images/logo.jpg',
                                    width: logoSize,
                                    height: logoSize,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      // Fallback to icon if image fails to load
                                      return Container(
                                        width: logoSize,
                                        height: logoSize,
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.15),
                                          shape: BoxShape.circle,
                                          gradient: const LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [
                                              Color(0xFF667eea),
                                              Color(0xFF764ba2),
                                            ],
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.pool_rounded,
                                          size: logoSize * 0.4,
                                          color: Colors.white,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    
                    const SizedBox(height: 50),
                    
                    // Animated App Title
                  
                    
                    // Animated Subtitle
                    FadeTransition(
                      opacity: _textAnimation,
                      child: const Text(
                        'Track • Improve • Achieve',
                        style: TextStyle(
                          fontSize: 20,
                          color: Colors.white70,
                          letterSpacing: 2.0,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                    ),
                    
                    const Spacer(flex: 2),
                    
                    // Loading Indicator
                    TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 2000),
                      builder: (context, value, child) {
                        return SizedBox(
                          width: 50,
                          height: 50,
                          child: CircularProgressIndicator(
                            strokeWidth: 4,
                            value: value,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white.withOpacity(0.9),
                            ),
                            backgroundColor: Colors.white.withOpacity(0.2),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    
                    // Status Message
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Text(
                        _statusMessage,
                        style: const TextStyle(
                          fontSize: 18,
                          color: Colors.white70,
                          fontWeight: FontWeight.w400,
                          letterSpacing: 0.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    
                    const Spacer(flex: 1),
                    
                    // Version with style
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: const Text(
                        'Version 1.0.0',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white60,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}