import 'package:flutter/material.dart';
import 'home_screen.dart'; 

void main() async {
  // 🌟 MAGIC FIX: यह लाइन पूरे ऐप के इंजन को स्टार्ट कर देगी जिससे लोडिंग नहीं अटकेगी! 🌟
  WidgetsFlutterBinding.ensureInitialized(); 
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Pro Tube',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F0F0F),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF0F0F0F),
          selectedItemColor: Colors.white,
          unselectedItemColor: Colors.grey,
          type: BottomNavigationBarType.fixed,
        ),
      ),
      home: const YouTubeHomeScreen(),
    );
  }
}
