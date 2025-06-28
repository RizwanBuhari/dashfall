import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'widgets/start_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // 3. Initialize the Mobile Ads SDK
  MobileAds.instance.initialize();
  runApp(const DashFallApp());
}

class DashFallApp extends StatelessWidget {
  const DashFallApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DashFall',
      theme: ThemeData.light(),
      home: const StartScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}