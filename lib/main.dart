import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'widgets/start_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:dashfallgame/widgets/create_username_screen.dart';
import 'firebase_options.dart';
import 'package:dashfallgame/player_prefs.dart';


void main() async { // <--- MAKE THIS CHANGE
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  MobileAds.instance.initialize();
  String? savedUsername = await PlayerPreferences.getPlayerUsername();
  runApp(DashFallApp(initialUsername: savedUsername));
}

class DashFallApp extends StatelessWidget {
  final String? initialUsername;
  const DashFallApp({super.key, this.initialUsername});


  @override
  Widget build(BuildContext context) {
    Widget initialScreen;
    if (initialUsername == null || initialUsername!.isEmpty) {
      initialScreen = const CreateUsernameScreen();
    } else {
      initialScreen = const StartScreen();
    }
    return MaterialApp(
      title: 'DashFall',
      theme: ThemeData.light(),
      home: initialScreen,
      debugShowCheckedModeBanner: false,
    );
  }
}