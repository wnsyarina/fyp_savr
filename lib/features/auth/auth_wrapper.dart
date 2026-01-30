import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fyp_savr/features/auth/pages/landing_page.dart';
import 'package:fyp_savr/features/customer/pages/home_page.dart';
import 'package:fyp_savr/features/merchant/pages/merchant_dashboard.dart';
import 'package:fyp_savr/features/admin/pages/super_admin_dashboard.dart';
import 'package:fyp_savr/data/services/user_service.dart';
import 'package:fyp_savr/data/services/firebase_service.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData && snapshot.data != null) {
          final user = snapshot.data!;
          print('User authenticated: ${user.email}');
          return _buildAuthenticatedUser(context, user);
        }

        print('No user found, showing landing page');
        return const LandingPage();
      },
    );
  }

  Widget _buildAuthenticatedUser(BuildContext context, User user) {
    print('Building authenticated user: ${user.uid}');
    print('Email verified: ${user.emailVerified}');

    // Skip email verification during test
    // if (!user.emailVerified) {
    //   print('Email not verified, showing verification page');
    //   return EmailVerificationPage(user: user);
    // }

    return FutureBuilder<Map<String, dynamic>?>(
      future: UserService.getUser(user.uid),
      builder: (context, userSnapshot) {
        if (userSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (!userSnapshot.hasData || userSnapshot.data == null) {
          print('⚠️ User data not found for UID: ${user.uid}');
          print('⚠️ This could be a deleted user trying to log in');

          return FutureBuilder(
            future: FirebaseService.restaurants.doc(user.uid).get(),
            builder: (context, restaurantSnapshot) {
              if (restaurantSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              if (restaurantSnapshot.hasData && restaurantSnapshot.data!.exists) {
                print('⚠️ Found orphaned restaurant for deleted user: ${user.uid}');

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) => AlertDialog(
                      title: const Text('Account Deleted'),
                      content: const Text(
                        'Your account has been deleted by an administrator. '
                            'Please contact support if you believe this is an error.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () async {
                            await FirebaseAuth.instance.signOut();
                            Navigator.pop(context);
                          },
                          child: const Text('OK'),
                        ),
                      ],
                    ),
                  );
                });

                return const Scaffold(
                  body: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Logging out...'),
                      ],
                    ),
                  ),
                );
              }

              return const LandingPage();
            },
          );
        }

        final userData = userSnapshot.data!;

        print('=== USER DATA ===');
        print('Role: ${userData['role']}');
        print('Email: ${userData['email']}');
        print('UID: ${user.uid}');
        print('=================');

        final role = userData['role']?.toString().trim().toLowerCase() ?? 'customer';
        print('User role determined: $role');

        if (role == 'merchant') {
          return _verifyMerchantRestaurant(context, user.uid, role);
        }

        return _buildRoleBasedHome(role, userData);
      },
    );
  }

  Widget _verifyMerchantRestaurant(BuildContext context, String merchantId, String role) {
    print('Verifying merchant restaurant for: $merchantId');

    return FutureBuilder(
      future: FirebaseService.restaurants.doc(merchantId).get(),
      builder: (context, restaurantSnapshot) {
        if (restaurantSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (!restaurantSnapshot.hasData || !restaurantSnapshot.data!.exists) {
          print('❌ Merchant $merchantId has no restaurant!');

          return FutureBuilder(
            future: UserService.getUser(merchantId),
            builder: (context, userDataSnapshot) {
              String userName = 'Merchant';
              if (userDataSnapshot.hasData && userDataSnapshot.data != null) {
                userName = userDataSnapshot.data!['name'] ?? 'Merchant';
              }

              WidgetsBinding.instance.addPostFrameCallback((_) {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => AlertDialog(
                    title: const Text('Account Error'),
                    content: Text(
                      'Hello $userName,\n\n'
                          'Your merchant account appears to be incomplete or corrupted. '
                          'This could happen if:\n'
                          '• Your restaurant registration was rejected\n'
                          '• There was a system error\n'
                          '• Your account is being reviewed\n\n'
                          'Please contact support for assistance.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () async {
                          await FirebaseAuth.instance.signOut();
                          Navigator.pop(context);
                        },
                        child: const Text('Logout'),
                      ),
                    ],
                  ),
                );
              });

              return const Scaffold(
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error, color: Colors.orange, size: 64),
                      SizedBox(height: 16),
                      Text('Verifying account...'),
                    ],
                  ),
                ),
              );
            },
          );
        }

        print('✅ Merchant restaurant verified for: $merchantId');
        return _buildRoleBasedHome(role, {});
      },
    );
  }

  Widget _buildRoleBasedHome(String role, Map<String, dynamic> userData) {
    print('Navigating to dashboard for role: $role');

    if (role == 'super_admin' || role == 'admin') {
      print('Redirecting to SuperAdminDashboard (role: $role)');
      return const SuperAdminDashboard();
    }

    switch (role) {
      case 'merchant':
        print('Redirecting to MerchantDashboard');
        return const MerchantDashboard();
      case 'customer':
        print('Redirecting to CustomerHomePage');
        return const CustomerHomePage();
      default:
        print('⚠️ Unknown role: $role, defaulting to CustomerHomePage');
        return const CustomerHomePage();
    }
  }
}