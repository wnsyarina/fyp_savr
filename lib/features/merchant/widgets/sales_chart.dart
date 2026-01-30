import 'package:flutter/material.dart';

class SalesChart extends StatelessWidget {
  final Map<String, double> weeklySales;
  final double maxSales;

  const SalesChart({
    super.key,
    required this.weeklySales,
    required this.maxSales,
  });

  @override
  Widget build(BuildContext context) {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Weekly Sales',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: days.asMap().entries.map((entry) {
                  final index = entry.key;
                  final day = entry.value;
                  final sales = weeklySales[day.toLowerCase()] ?? 0.0;
                  final height = maxSales > 0 ? (sales / maxSales * 150) : 0.0;

                  return Expanded(
                    child: Column(
                      children: [
                        Text(
                          'RM${sales.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.deepOrange,
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(4),
                                ),
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [
                                    Colors.deepOrange,
                                    Colors.deepOrange.withOpacity(0.7),
                                  ],
                                ),
                              ),
                              height: height,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          day,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total Weekly Sales',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'RM0.00',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.deepOrange,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}