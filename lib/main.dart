import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:fyp_savr/data/services/firebase_service.dart';
import 'package:fyp_savr/features/auth/auth_wrapper.dart';
import 'package:fyp_savr/firebase_options.dart';
import 'package:fyp_savr/utils/network_wrapper.dart';
import 'data/services/network_service.dart';
import 'data/services/push_notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  bool hasInternetOnStartup = await NetworkService.hasInternetConnection();
  if (hasInternetOnStartup) {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      await FirebaseService.init();
      await PushNotificationService.initialize();
    } catch (e) {
      print('Firebase init failed but continuing: $e');
    }
  } else {
    print('No internet at startup - skipping Firebase');
  }

  runApp(const SavrApp());
}

class SavrApp extends StatelessWidget {
  const SavrApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        title: 'Savr',
        navigatorKey: PushNotificationService.navigatorKey,
        theme: ThemeData(
          primarySwatch: Colors.deepOrange,
          colorScheme: ColorScheme.light(
            primary: Colors.orange,
            secondary: Colors.orangeAccent,
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
          ),
          appBarTheme: const AppBarTheme(
            elevation: 0,
            centerTitle: true,
          ),
          fontFamily: 'Sen',
        ),
        home: NetworkWrapper(
            child: const AuthWrapper(),
        ),
        debugShowCheckedModeBanner: false,
    );
  }
}