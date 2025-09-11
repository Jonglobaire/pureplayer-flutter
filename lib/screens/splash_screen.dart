import 'package:flutter/material.dart';
import '../utils/device_info.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  String _deviceInfo = '';
  bool _navigated = false; // Prevents double navigation

  @override
  void initState() {
    super.initState();
    debugPrint("🔄 SplashScreen: Initializing...");

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOutCubic,
    ));

    _loadDeviceInfo();
    _animationController.forward();

    // Navigate to home screen after 3 seconds
    Future.delayed(const Duration(seconds: 3), _navigateToHome);
  }

  Future<void> _loadDeviceInfo() async {
    try {
      final macAddress = await DeviceInfoHelper.getMacAddress();
      final deviceModel = await DeviceInfoHelper.getDeviceModel();

      if (mounted) {
        setState(() {
          _deviceInfo = '$deviceModel\nDevice ID: $macAddress';
        });
        debugPrint("📱 Device Info Loaded: $_deviceInfo");
      }
    } catch (e, stackTrace) {
      debugPrint("❌ Failed to load device info: $e");
      debugPrint(stackTrace.toString());
    }
  }

  void _navigateToHome() {
    if (!mounted || _navigated) return;
    _navigated = true;
    debugPrint("✅ SplashScreen: Navigating to HomeScreen...");
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const HomeScreen()),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
    debugPrint("🗑️ SplashScreen disposed");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D47A1),
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // App Logo
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: const Color(0xFFE50914),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFE50914).withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    'P',
                    style: TextStyle(
                      fontSize: 60,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 30),

              // App Name
              const Text(
                'Pure Player',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 10),

              // Subtitle
              const Text(
                'IPTV Streaming Player',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 50),

              // Loading indicator
              const CircularProgressIndicator(
                color: Color(0xFFE50914),
                strokeWidth: 3,
              ),
              const SizedBox(height: 30),

              // Device info
              if (_deviceInfo.isNotEmpty)
                Text(
                  _deviceInfo,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
