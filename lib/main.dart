import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Force landscape orientation globally
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  
  // Load saved playlist URL
  final prefs = await SharedPreferences.getInstance();
  final savedUrl = prefs.getString('playlistUrl');
  
  runApp(PurePlayerApp(initialPlaylistUrl: savedUrl));
}

class PurePlayerApp extends StatelessWidget {
  final String? initialPlaylistUrl;
  
  const PurePlayerApp({super.key, this.initialPlaylistUrl});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pure Player',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFE50914), // Netflix red
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: Colors.black,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          systemOverlayStyle: SystemUiOverlayStyle.light,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFE50914),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          ),
        ),
      ),
      home: HomeScreen(initialPlaylistUrl: initialPlaylistUrl),
    );
  }
}