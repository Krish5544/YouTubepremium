import 'package:flutter/material.dart';
import 'home_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ProTube',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: Colors.red,
        scaffoldBackgroundColor: const Color(0xFF0F0F0F),
      ),
      // 🌟 यहाँ ध्यान दो भाई! 🌟
      // हमने MaterialApp के अंदर सीधे home_screen को कॉल करने के बजाय
      // एक Builder विजेट लगाया है ताकि हमारे मिनीप्लेयर Overlay को ऐप का सही Context मिल सके।
      home: Builder(
        builder: (context) => const YouTubeHomeScreen(),
      ),
    );
  }
}
