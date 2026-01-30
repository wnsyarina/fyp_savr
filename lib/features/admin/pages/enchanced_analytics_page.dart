import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:fyp_savr/data/services/enchanced_analytics_service.dart';
import 'package:fyp_savr/utils/helpers.dart';

class EnhancedAnalyticsPage extends StatefulWidget {
  const EnhancedAnalyticsPage({super.key});

  @override
  State<EnhancedAnalyticsPage> createState() => _EnhancedAnalyticsPageState();
}

class _EnhancedAnalyticsPageState extends State<EnhancedAnalyticsPage> {
  final Map<String, dynamic> _analyticsData = {};
  bool _isLoading = true;
  int _selectedTimeframe = 30;
  int _touchedIndex = -1;

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    setState(() => _isLoading = true);

    try {
      final growthData = await EnhancedAnalyticsService.getPlatformGrowthData(days: _selectedTimeframe);
      final revenueData = await EnhancedAnalyticsService.getRevenueAnalytics(days: _selectedTimeframe);
      final categoryData = await EnhancedAnalyticsService.getCategoryPerformance();

      setState(() {
        _analyticsData['growth'] = growthData;
        _analyticsData['revenue'] = revenueData;
        _analyticsData['categories'] = categoryData;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading analytics: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadAnalytics,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _buildTimeframeSelector(),
              const SizedBox(height: 20),
              _buildGrowthChart(),
              const SizedBox(height: 20),
              _buildRevenueChart(),
              const SizedBox(height: 20),
              _buildCategoryChart(),
              const SizedBox(height: 20),
              _buildKeyMetrics(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimeframeSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              'Timeframe',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [7, 30, 90].map((days) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: FilterChip(
                    label: Text('$days Days'),
                    selected: _selectedTimeframe == days,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _selectedTimeframe = days);
                        _loadAnalytics();
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrowthChart() {
    final growthData = _analyticsData['growth'] ?? {};
    final userGrowth = (growthData['userGrowth'] as Map<String, dynamic>?) ?? {};
    final restaurantGrowth = (growthData['restaurantGrowth'] as Map<String, dynamic>?) ?? {};
    final orderGrowth = (growthData['orderGrowth'] as Map<String, dynamic>?) ?? {};

    final userSpots = _convertToLineSpots(userGrowth);
    final restaurantSpots = _convertToLineSpots(restaurantGrowth);
    final orderSpots = _convertToLineSpots(orderGrowth);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Platform Growth',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: true),
                  titlesData: FlTitlesData(show: false),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: userSpots,
                      isCurved: true,
                      color: Colors.blue,
                      barWidth: 4,
                      isStrokeCapRound: true,
                      dotData: FlDotData(show: false),
                      belowBarData: BarAreaData(show: false),
                    ),
                    LineChartBarData(
                      spots: restaurantSpots,
                      isCurved: true,
                      color: Colors.green,
                      barWidth: 4,
                      isStrokeCapRound: true,
                      dotData: FlDotData(show: false),
                      belowBarData: BarAreaData(show: false),
                    ),
                    LineChartBarData(
                      spots: orderSpots,
                      isCurved: true,
                      color: Colors.purple,
                      barWidth: 4,
                      isStrokeCapRound: true,
                      dotData: FlDotData(show: false),
                      belowBarData: BarAreaData(show: false),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            _buildChartLegend(),
          ],
        ),
      ),
    );
  }

  Widget _buildRevenueChart() {
    final revenueData = _analyticsData['revenue'] ?? {};
    final dailyRevenue = (revenueData['dailyRevenue'] as Map<String, dynamic>?) ?? {};

    final revenueBars = _convertToBarChartData(dailyRevenue);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Daily Revenue',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: _getMaxRevenue(dailyRevenue) * 1.1,
                  barGroups: revenueBars,
                  gridData: FlGridData(show: true),
                  titlesData: FlTitlesData(show: false),
                  borderData: FlBorderData(show: false),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChart() {
    final categoryData = _analyticsData['categories'] ?? {};
    final categoryRevenue = (categoryData['categoryRevenue'] as Map<String, dynamic>?) ?? {};

    final pieSections = _convertToPieChartData(categoryRevenue);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '🏷Revenue by Category',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 300,
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: PieChart(
                      PieChartData(
                        sections: pieSections,
                        centerSpaceRadius: 40,
                        sectionsSpace: 2,
                        pieTouchData: PieTouchData(
                          touchCallback: (FlTouchEvent event, pieTouchResponse) {
                            setState(() {
                              if (!event.isInterestedForInteractions ||
                                  pieTouchResponse == null ||
                                  pieTouchResponse.touchedSection == null) {
                                _touchedIndex = -1;
                                return;
                              }
                              _touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                            });
                          },
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: _buildCategoryLegend(categoryRevenue),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryLegend(Map<String, dynamic> categoryRevenue) {
    final categories = categoryRevenue.entries.toList();

    return ListView.builder(
      shrinkWrap: true,
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final entry = categories[index];
        final color = _getColorForCategory(entry.key);
        final isTouched = index == _touchedIndex;
        final fontSize = isTouched ? 14.0 : 12.0;
        final fontWeight = isTouched ? FontWeight.bold : FontWeight.normal;

        final value = (entry.value as num?)?.toDouble() ?? 0.0;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                color: color,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  entry.key,
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: fontWeight,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                Helpers.formatCurrency(value),
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: fontWeight,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildChartLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildLegendItem('Users', Colors.blue),
        const SizedBox(width: 16),
        _buildLegendItem('Restaurants', Colors.green),
        const SizedBox(width: 16),
        _buildLegendItem('Orders', Colors.purple),
      ],
    );
  }

  Widget _buildLegendItem(String text, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          color: color,
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildKeyMetrics() {
    final revenueData = _analyticsData['revenue'] ?? {};
    final growthData = _analyticsData['growth'] ?? {};

    final userGrowth = (growthData['userGrowth'] as Map<String, dynamic>?) ?? {};
    final restaurantGrowth = (growthData['restaurantGrowth'] as Map<String, dynamic>?) ?? {};

    final totalUsers = userGrowth.values.fold<int>(0, (sum, value) {
      if (value is int) return sum + value;
      if (value is num) return sum + value.toInt();
      return sum;
    });

    final totalRestaurants = restaurantGrowth.values.fold<int>(0, (sum, value) {
      if (value is int) return sum + value;
      if (value is num) return sum + value.toInt();
      return sum;
    });

    final totalRevenue = (revenueData['totalRevenue'] as num?)?.toDouble() ?? 0.0;
    final totalOrders = (revenueData['totalOrders'] as num?)?.toInt() ?? 0;
    final avgOrderValue = (revenueData['averageOrderValue'] as num?)?.toDouble() ?? 0.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Key Metrics',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              children: [
                _MetricCard(
                  title: 'Total Revenue',
                  value: Helpers.formatCurrency(totalRevenue),
                  icon: Icons.attach_money,
                  color: Colors.green,
                ),
                _MetricCard(
                  title: 'Total Orders',
                  value: Helpers.formatLargeNumber(totalOrders),
                  icon: Icons.shopping_cart,
                  color: Colors.blue,
                ),
                _MetricCard(
                  title: 'Avg Order Value',
                  value: Helpers.formatCurrency(avgOrderValue),
                  icon: Icons.trending_up,
                  color: Colors.orange,
                ),
                _MetricCard(
                  title: 'New Users',
                  value: Helpers.formatLargeNumber(totalUsers),
                  icon: Icons.people,
                  color: Colors.purple,
                ),
                _MetricCard(
                  title: 'New Restaurants',
                  value: Helpers.formatLargeNumber(totalRestaurants),
                  icon: Icons.restaurant,
                  color: Colors.teal,
                ),
                _MetricCard(
                  title: 'Timeframe',
                  value: '${_selectedTimeframe} days',
                  icon: Icons.calendar_today,
                  color: Colors.red,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<FlSpot> _convertToLineSpots(Map<String, dynamic> data) {
    final entries = data.entries.toList();
    return entries.asMap().entries.map((entry) {
      final index = entry.key.toDouble();
      final value = _safeParseDouble(entry.value.value);
      return FlSpot(index, value);
    }).toList();
  }

  List<BarChartGroupData> _convertToBarChartData(Map<String, dynamic> data) {
    final entries = data.entries.toList();
    return entries.asMap().entries.map((entry) {
      final index = entry.key;
      final value = _safeParseDouble(entry.value.value);

      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: value,
            color: _getColorForIndex(index),
            width: 16,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      );
    }).toList();
  }

  List<PieChartSectionData> _convertToPieChartData(Map<String, dynamic> data) {
    final total = data.values.fold(0.0, (sum, value) => sum + _safeParseDouble(value));
    if (total == 0) return [];

    final entries = data.entries.toList();
    return entries.asMap().entries.map((entry) {
      final index = entry.key;
      final category = entry.value.key;
      final value = _safeParseDouble(entry.value.value);
      final percentage = (value / total * 100);

      final isTouched = index == _touchedIndex;
      final radius = isTouched ? 50.0 : 40.0;

      return PieChartSectionData(
        color: _getColorForCategory(category.toString()),
        value: value,
        title: '${percentage.toStringAsFixed(1)}%',
        radius: radius,
        titleStyle: TextStyle(
          fontSize: isTouched ? 14 : 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();
  }

  double _safeParseDouble(dynamic value) {
    if (value is int) return value.toDouble();
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return 0.0;
  }

  double _getMaxRevenue(Map<String, dynamic> data) {
    if (data.isEmpty) return 100.0;
    final values = data.values.map((v) => _safeParseDouble(v));
    return values.reduce((a, b) => a > b ? a : b);
  }

  Color _getColorForCategory(String category) {
    return Helpers.getColorForCategory(category);
  }

  Color _getColorForIndex(int index) {
    return Helpers.getColorForIndex(index);
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricCard({
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
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}