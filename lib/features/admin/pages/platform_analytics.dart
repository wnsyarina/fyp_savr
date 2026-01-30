import 'package:flutter/material.dart';
import 'package:fyp_savr/data/services/super_admin_service.dart';

class PlatformAnalyticsPage extends StatefulWidget {
  const PlatformAnalyticsPage({super.key});

  @override
  State<PlatformAnalyticsPage> createState() => _PlatformAnalyticsPageState();
}

class _PlatformAnalyticsPageState extends State<PlatformAnalyticsPage> {
  Map<String, dynamic> _stats = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }
  
Future<void> _loadStats() async {
  try {
    final stats = await SuperAdminService.getPlatformStats();
    setState(() {
      _stats = stats;
      _isLoading = false;
    });
  } catch (e) {
    setState(() {
      _isLoading = false;
      _stats = {
        'totalUsers': 0,
        'totalRestaurants': 0,
        'pendingVerifications': 0,
        'totalOrders': 0,
      };
    });
  }
}

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          GridView.count(
            shrinkWrap: true,
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            children: [
              _StatCard(
                title: 'Total Users',
                value: _stats['totalUsers'].toString(),
                icon: Icons.people,
                color: Colors.blue,
              ),
              _StatCard(
                title: 'Total Restaurants',
                value: _stats['totalRestaurants'].toString(),
                icon: Icons.restaurant,
                color: Colors.green,
              ),
              _StatCard(
                title: 'Pending Verifications',
                value: _stats['pendingVerifications'].toString(),
                icon: Icons.pending,
                color: Colors.orange,
              ),
              _StatCard(
                title: 'Total Orders',
                value: _stats['totalOrders'].toString(),
                icon: Icons.shopping_cart,
                color: Colors.purple,
              ),
            ],
          ),
          const SizedBox(height: 32),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Quick Actions',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ActionChip(
                        avatar: const Icon(Icons.refresh, size: 16),
                        label: const Text('Refresh Stats'),
                        onPressed: _loadStats,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}