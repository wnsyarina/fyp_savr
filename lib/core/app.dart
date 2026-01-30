import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fyp_savr/features/auth/pages/landing_page.dart';
import 'package:fyp_savr/features/customer/pages/home_page.dart';
import 'package:fyp_savr/features/merchant/pages/merchant_dashboard.dart';
import 'package:fyp_savr/features/admin/pages/super_admin_dashboard.dart';
import 'package:fyp_savr/data/services/user_service.dart';

class AppWrapper extends StatelessWidget {
  const AppWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SplashScreen();
        }

        if (snapshot.hasData) {
          return FutureBuilder<Map<String, dynamic>?>(
            future: UserService.getUser(snapshot.data!.uid),
            builder: (context, userSnapshot) {
              if (userSnapshot.connectionState == ConnectionState.waiting) {
                return const SplashScreen();
              }

              if (userSnapshot.hasData) {
                final userData = userSnapshot.data!;
                return _buildAppByRole(userData['role']);
              }

              return const LandingPage();
            },
          );
        }

        return const LandingPage();
      },
    );
  }

  Widget _buildAppByRole(String role) {
    switch (role) {
      case 'super_admin':
        return const SuperAdminDashboard();
      case 'merchant':
        return const MerchantDashboard();
      case 'customer':
      default:
        return const CustomerHomePage();
    }
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FlutterLogo(size: 100),
            const SizedBox(height: 20),
            const CircularProgressIndicator(),
            const SizedBox(height: 20),
            const Text('Savr', style: TextStyle(fontSize: 24)),
          ],
        ),
      ),
    );
  }
}