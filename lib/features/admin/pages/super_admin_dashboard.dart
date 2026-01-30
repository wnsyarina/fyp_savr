import 'package:flutter/material.dart';
import 'package:fyp_savr/data/services/firebase_service.dart';
import 'package:fyp_savr/features/admin/pages/restaurant_verifications.dart';
import 'package:fyp_savr/features/admin/pages/user_management.dart';
import 'package:fyp_savr/features/admin/pages/enchanced_analytics_page.dart';

class SuperAdminDashboard extends StatefulWidget {
  const SuperAdminDashboard({super.key});

  @override
  State<SuperAdminDashboard> createState() => _SuperAdminDashboardState();
}

class _SuperAdminDashboardState extends State<SuperAdminDashboard> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    RestaurantVerificationsPage(),
    UserManagementPage(),
    EnhancedAnalyticsPage(),
  ];

  final List<String> _pageTitles = [
    'Restaurant Verifications',
    'User Management',
    'Platform Analytics',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_pageTitles[_currentIndex]),
        backgroundColor: Colors.purple,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        selectedItemColor: Colors.purple,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment),
            label: 'Verifications',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'Users',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics),
            label: 'Analytics',
          ),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    await FirebaseService.auth.signOut();
  }
}