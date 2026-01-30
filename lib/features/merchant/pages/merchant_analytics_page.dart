import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fyp_savr/data/services/enchanced_analytics_service.dart';
import 'package:fyp_savr/data/services/firebase_service.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:fyp_savr/data/services/food_service.dart';
import 'package:fyp_savr/data/services/restaurant_service.dart';

class MerchantAnalyticsPage extends StatefulWidget {
  const MerchantAnalyticsPage({super.key});

  @override
  State<MerchantAnalyticsPage> createState() => _MerchantAnalyticsPageState();
}

class _MerchantAnalyticsPageState extends State<MerchantAnalyticsPage> {
  final List<String> _timeRanges = ['7 days', '30 days', '90 days', 'All time'];
  String _selectedTimeRange = '30 days';
  Map<String, dynamic>? _performanceData;
  Map<String, dynamic>? _revenueData;
  Map<String, dynamic>? _foodPerformance;
  Map<String, dynamic>? _performanceMetrics;
  Map<String, dynamic>? _restaurantData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    setState(() => _isLoading = true);

    try {
      final user = FirebaseService.auth.currentUser;
      if (user != null) {
        final days = _getDaysFromTimeRange(_selectedTimeRange);

        final restaurantDoc = await FirebaseService.getRestaurantByMerchantId(user.uid);

        if (restaurantDoc == null) {
          setState(() {
            _isLoading = false;
            _performanceData = {};
            _revenueData = {};
            _foodPerformance = {};
            _performanceMetrics = {};
          });
          return;
        }

        final restaurantId = restaurantDoc['id'];

        final [performance, revenue, foodPerformance, metrics] = await Future.wait([
          EnhancedAnalyticsService.getMerchantPerformance(restaurantId, days: days),
          EnhancedAnalyticsService.getRevenueAnalyticsForMerchant(user.uid, days: days),
          FoodService.getFoodPerformance(restaurantId, days: days),
          _fetchPerformanceMetrics(restaurantId, days: days),
        ]);

        setState(() {
          _performanceData = performance as Map<String, dynamic>;
          _revenueData = revenue as Map<String, dynamic>;
          _foodPerformance = foodPerformance as Map<String, dynamic>;
          _performanceMetrics = metrics as Map<String, dynamic>;
          _restaurantData = restaurantDoc;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading analytics: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<Map<String, dynamic>> _fetchPerformanceMetrics(String restaurantId, {int days = 30}) async {
    final startDate = DateTime.now().subtract(Duration(days: days));

    try {
      final restaurantDoc = await FirebaseService.restaurants.doc(restaurantId).get();
      final restaurantData = restaurantDoc.data() as Map<String, dynamic>?;
      final rating = (restaurantData?['rating'] ?? 0.0).toDouble();

      final ordersQuery = await FirebaseService.orders
          .where('restaurantId', isEqualTo: restaurantId)
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .get();

      int totalOrders = ordersQuery.docs.length;
      int completedOrders = 0;

      for (final order in ordersQuery.docs) {
        final data = order.data() as Map<String, dynamic>;
        if (data['status'] == 'completed' || data['status'] == 'delivered') {
          completedOrders++;
        }
      }

      final orderCompletionRate = totalOrders > 0 ? (completedOrders / totalOrders * 100) : 0.0;

      final currentPerformance = await EnhancedAnalyticsService.getMerchantPerformance(
          restaurantId,
          days: days
      );
      final salesTrend = currentPerformance['salesTrend'] ?? 0.0;

      final foodPerf = await FoodService.getFoodPerformance(restaurantId, days: days);
      final popularItemsCount = (foodPerf['topSelling'] as List).length;

      return {
        'salesTrend': salesTrend,
        'popularItemsCount': popularItemsCount,
        'orderCompletionRate': orderCompletionRate,
        'rating': rating,
        'totalOrders': totalOrders,
        'completedOrders': completedOrders,
      };

    } catch (e) {
      print('Error fetching performance metrics: $e');
      return {
        'salesTrend': 0.0,
        'popularItemsCount': 0,
        'orderCompletionRate': 0.0,
        'rating': 0.0,
        'totalOrders': 0,
        'completedOrders': 0,
      };
    }
  }

  int _getDaysFromTimeRange(String range) {
    switch (range) {
      case '7 days': return 7;
      case '30 days': return 30;
      case '90 days': return 90;
      default: return 365;
    }
  }

  Widget _buildTimeRangeSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Time Range',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _timeRanges.map((range) {
                final isSelected = _selectedTimeRange == range;
                return ChoiceChip(
                  label: Text(range),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _selectedTimeRange = range);
                      _loadAnalytics();
                    }
                  },
                  selectedColor: Colors.deepOrange,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : Colors.black,
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRevenueCard() {
    if (_revenueData == null) return const SizedBox();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Revenue Overview',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    title: 'Total Revenue',
                    value: 'RM${_revenueData!['totalRevenue']?.toStringAsFixed(2) ?? '0.00'}',
                    icon: Icons.attach_money,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    title: 'Total Orders',
                    value: '${_revenueData!['totalOrders'] ?? 0}',
                    icon: Icons.shopping_bag,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildStatCard(
              title: 'Average Order Value',
              value: 'RM${_revenueData!['averageOrderValue']?.toStringAsFixed(2) ?? '0.00'}',
              icon: Icons.trending_up,
              color: Colors.purple,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopSellingFoods() {
    if (_foodPerformance == null ||
        (_foodPerformance!['topSelling'] as List).isEmpty) {
      return const SizedBox();
    }

    final topSelling = _foodPerformance!['topSelling'] as List;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Top Selling Items',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...topSelling.take(5).map((item) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.deepOrange[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.fastfood, color: Colors.deepOrange),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['name'] ?? 'Unknown',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '${item['totalSold']} sold • RM${item['totalRevenue']?.toStringAsFixed(2) ?? '0.00'}',
                            style: TextStyle(color: Colors.grey[600], fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Chip(
                      label: Text('#${topSelling.indexOf(item) + 1}'),
                      backgroundColor: Colors.deepOrange[100],
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildSalesTrendChart() {
    if (_performanceData == null ||
        (_performanceData!['dailyRevenue'] as Map).isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            children: [
              Icon(Icons.analytics, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 16),
              const Text(
                'No sales data available',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Start selling to see your analytics',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    final dailyRevenue = _performanceData!['dailyRevenue'] as Map<String, dynamic>;
    final chartData = dailyRevenue.entries.map((entry) {
      return SalesData(entry.key, entry.value as double);
    }).toList();

    chartData.sort((a, b) => a.date.compareTo(b.date));

    final showLabelsEvery = chartData.length > 4 ? (chartData.length ~/ 4) : 1;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Daily Revenue Trend',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: false),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index >= 0 &&
                              index < chartData.length &&
                              showLabelsEvery > 0 &&
                              index % showLabelsEvery == 0) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                chartData[index].date,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey,
                                ),
                              ),
                            );
                          }
                          return const SizedBox();
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            'RM${value.toInt()}',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.grey,
                            ),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border.all(
                      color: Colors.grey[300]!,
                      width: 1,
                    ),
                  ),
                  minX: 0,
                  maxX: chartData.length > 0 ? (chartData.length - 1).toDouble() : 0,
                  minY: 0,
                  maxY: chartData.isNotEmpty
                      ? (chartData
                      .map((e) => e.revenue)
                      .reduce((a, b) => a > b ? a : b) * 1.1)
                      : 100,
                  lineBarsData: [
                    LineChartBarData(
                      spots: chartData
                          .asMap()
                          .entries
                          .map((entry) => FlSpot(
                        entry.key.toDouble(),
                        entry.value.revenue,
                      ))
                          .toList(),
                      isCurved: true,
                      color: Colors.deepOrange,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.deepOrange.withOpacity(0.3),
                            Colors.deepOrange.withOpacity(0.1),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.deepOrange,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Daily Revenue',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics Dashboard'),
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAnalytics,
            tooltip: 'Refresh Analytics',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildTimeRangeSelector(),
            const SizedBox(height: 16),
            _buildRevenueCard(),
            const SizedBox(height: 16),
            _buildSalesTrendChart(),
            const SizedBox(height: 16),
            _buildTopSellingFoods(),
            const SizedBox(height: 16),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Performance Metrics',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    GridView.count(
                      shrinkWrap: true,
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      children: [
                        _buildMetricCard(
                          title: 'Sales Trend',
                          value: '${(_performanceMetrics?['salesTrend'] ?? 0.0).toStringAsFixed(1)}%',
                          icon: Icons.trending_up,
                          isPositive: (_performanceMetrics?['salesTrend'] ?? 0) > 0,
                        ),
                        _buildMetricCard(
                          title: 'Popular Items',
                          value: '${_performanceMetrics?['popularItemsCount'] ?? 0}',
                          icon: Icons.star,
                          isPositive: true,
                        ),
                        _buildMetricCard(
                          title: 'Order Completion',
                          value: '${(_performanceMetrics?['orderCompletionRate'] ?? 0.0).toStringAsFixed(0)}%',
                          subtitle: '${_performanceMetrics?['completedOrders'] ?? 0}/${_performanceMetrics?['totalOrders'] ?? 0} orders',
                          icon: Icons.check_circle,
                          isPositive: (_performanceMetrics?['orderCompletionRate'] ?? 0) >= 90,
                        ),
                        _buildMetricCard(
                          title: 'Customer Rating',
                          value: (_performanceMetrics?['rating'] ?? 0.0).toStringAsFixed(1),
                          subtitle: 'Based on ${_restaurantData?['totalReviews'] ?? 0} reviews',
                          icon: Icons.star_rate,
                          isPositive: true,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required bool isPositive,
    String? subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isPositive ? Colors.green[50] : Colors.red[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isPositive ? Colors.green[100]! : Colors.red[100]!,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: isPositive ? Colors.green : Colors.red),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isPositive ? Colors.green[800] : Colors.red[800],
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.grey,
              ),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class SalesData {
  final String date;
  final double revenue;

  SalesData(this.date, this.revenue);
}