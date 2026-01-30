import 'package:flutter/material.dart';
import 'package:fyp_savr/data/models/user_role.dart';
import 'package:fyp_savr/data/services/firebase_service.dart';
import 'package:fyp_savr/features/customer/pages/home_page.dart';
import 'package:fyp_savr/features/merchant/pages/merchant_dashboard.dart';
import 'package:fyp_savr/features/admin/pages/super_admin_dashboard.dart';

class NavigationUtils {
  static Future<void> navigateBasedOnRole(BuildContext context, String uid) async {
    final role = await FirebaseService.getUserRole(uid);
    
    Widget destination;
    switch (role) {
      case UserRole.merchant:
        destination = const MerchantDashboard();
        break;
      case UserRole.superAdmin:
        destination = const SuperAdminDashboard();
        break;
      case UserRole.customer:
      default:
        destination = const CustomerHomePage();
    }

    if (context.mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => destination),
      );
    }
  }

  static Future<void> navigateAfterVerification(BuildContext context, String uid) async {
    await navigateBasedOnRole(context, uid);
  }
}