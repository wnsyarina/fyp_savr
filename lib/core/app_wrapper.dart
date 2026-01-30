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
        // Show loading while checking auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SplashScreen();
        }

        // User is logged in - check their role
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

              // User data not found, go to landing page
              return const LandingPage();
            },
          );
        }

        // User is not logged in
        return const LandingPage();
      },
    );
  }

  Widget _buildAppByRole(String role) {
    switch (role) {
      case 'super_admin':
        return const SuperAdminDashboard();
      case 'admin':
        return const SuperAdminDashboard(); // Use same for now
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
      backgroundColor: Colors.deepOrange,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // App Logo/Icon
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.restaurant,
                size: 60,
                color: Colors.deepOrange,
              ),
            ),
            const SizedBox(height: 30),
            // App Name
            const Text(
              'SAVR',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Save Food, Save Money',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 50),
            // Loading Indicator
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}