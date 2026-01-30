import 'package:flutter/material.dart';
import 'package:fyp_savr/data/services/restaurant_service.dart';
import 'package:fyp_savr/data/services/firebase_service.dart';

class RestaurantSettingsPage extends StatefulWidget {
  const RestaurantSettingsPage({super.key});

  @override
  State<RestaurantSettingsPage> createState() => _RestaurantSettingsPageState();
}

class _RestaurantSettingsPageState extends State<RestaurantSettingsPage> {
  Map<String, dynamic> _openingHours = {};
  bool _isLoading = true;
  bool _isSaving = false;

  final List<String> _timeOptions = [
    '00:00', '00:30', '01:00', '01:30', '02:00', '02:30', '03:00', '03:30',
    '04:00', '04:30', '05:00', '05:30', '06:00', '06:30', '07:00', '07:30',
    '08:00', '08:30', '09:00', '09:30', '10:00', '10:30', '11:00', '11:30',
    '12:00', '12:30', '13:00', '13:30', '14:00', '14:30', '15:00', '15:30',
    '16:00', '16:30', '17:00', '17:30', '18:00', '18:30', '19:00', '19:30',
    '20:00', '20:30', '21:00', '21:30', '22:00', '22:30', '23:00', '23:30',
  ];

  final List<Map<String, String>> _days = [
    {'key': 'monday', 'name': 'Monday'},
    {'key': 'tuesday', 'name': 'Tuesday'},
    {'key': 'wednesday', 'name': 'Wednesday'},
    {'key': 'thursday', 'name': 'Thursday'},
    {'key': 'friday', 'name': 'Friday'},
    {'key': 'saturday', 'name': 'Saturday'},
    {'key': 'sunday', 'name': 'Sunday'},
  ];

  @override
  void initState() {
    super.initState();
    _loadOpeningHours();
  }

  Future<void> _loadOpeningHours() async {
    try {
      final user = FirebaseService.auth.currentUser;
      if (user != null) {
        final hours = await RestaurantService.getRestaurantOpeningHoursByMerchantId(user.uid);
        setState(() {
          _openingHours = hours;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading opening hours: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveOpeningHours() async {
    setState(() => _isSaving = true);

    try {
      final user = FirebaseService.auth.currentUser;
      if (user != null) {
        await RestaurantService.updateRestaurantOpeningHoursByMerchantId(
          merchantId: user.uid,
          openingHours: _openingHours,
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Opening hours saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving opening hours: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _updateDayHours(String day, String field, dynamic value) {
    setState(() {
      if (!_openingHours.containsKey(day)) {
        _openingHours[day] = {'open': '10:00', 'close': '22:00', 'isClosed': false};
      }

      if (field == 'isClosed') {
        _openingHours[day]['isClosed'] = value;
      } else {
        _openingHours[day][field] = value;
      }
    });
  }

  Widget _buildDayCard(Map<String, String> day) {
    final dayData = _openingHours[day['key']] as Map<String, dynamic>? ?? {
      'open': '10:00',
      'close': '22:00',
      'isClosed': false,
    };

    final isClosed = dayData['isClosed'] ?? false;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  day['name']!,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Switch.adaptive(
                  value: !isClosed,
                  onChanged: (value) {
                    _updateDayHours(day['key']!, 'isClosed', !value);
                  },
                  activeColor: Colors.green,
                ),
              ],
            ),

            const SizedBox(height: 12),

            if (!isClosed) ...[
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Opening Time',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButton<String>(
                            value: dayData['open'] ?? '10:00',
                            isExpanded: true,
                            underline: const SizedBox(),
                            items: _timeOptions.map((time) {
                              return DropdownMenuItem(
                                value: time,
                                child: Text(time),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                _updateDayHours(day['key']!, 'open', value);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 16),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Closing Time',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButton<String>(
                            value: dayData['close'] ?? '22:00',
                            isExpanded: true,
                            underline: const SizedBox(),
                            items: _timeOptions.map((time) {
                              return DropdownMenuItem(
                                value: time,
                                child: Text(time),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                _updateDayHours(day['key']!, 'close', value);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              if (_compareTimes(dayData['close'] ?? '22:00', dayData['open'] ?? '10:00') <= 0)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.warning, color: Colors.orange, size: 16),
                      const SizedBox(width: 4),
                      const Text(
                        'Closing time should be after opening time',
                        style: TextStyle(fontSize: 12, color: Colors.orange),
                      ),
                    ],
                  ),
                ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Text(
                    'Closed',
                    style: TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  int _compareTimes(String time1, String time2) {
    final parts1 = time1.split(':');
    final parts2 = time2.split(':');

    final hour1 = int.parse(parts1[0]);
    final minute1 = parts1.length > 1 ? int.parse(parts1[1]) : 0;

    final hour2 = int.parse(parts2[0]);
    final minute2 = parts2.length > 1 ? int.parse(parts2[1]) : 0;

    if (hour1 != hour2) return hour1 - hour2;
    return minute1 - minute2;
  }

  Widget _buildQuickPresets() {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Quick Presets',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(
                  avatar: const Icon(Icons.business, size: 16),
                  label: const Text('Weekdays 9-5'),
                  onPressed: () {
                    setState(() {
                      for (final day in ['monday', 'tuesday', 'wednesday', 'thursday', 'friday']) {
                        _openingHours[day] = {
                          'open': '09:00',
                          'close': '17:00',
                          'isClosed': false,
                        };
                      }
                      for (final day in ['saturday', 'sunday']) {
                        if (!_openingHours.containsKey(day)) {
                          _openingHours[day] = {
                            'open': '10:00',
                            'close': '22:00',
                            'isClosed': false,
                          };
                        }
                      }
                    });
                  },
                ),

                ActionChip(
                  avatar: const Icon(Icons.restaurant, size: 16),
                  label: const Text('Restaurant Hours'),
                  onPressed: () {
                    setState(() {
                      for (final day in _days) {
                        _openingHours[day['key']!] = {
                          'open': '10:00',
                          'close': '22:00',
                          'isClosed': false,
                        };
                      }
                      _openingHours['friday'] = {
                        'open': '10:00',
                        'close': '23:00',
                        'isClosed': false,
                      };
                      _openingHours['saturday'] = {
                        'open': '10:00',
                        'close': '23:00',
                        'isClosed': false,
                      };
                    });
                  },
                ),

                ActionChip(
                  avatar: const Icon(Icons.access_time, size: 16),
                  label: const Text('24/7'),
                  onPressed: () {
                    setState(() {
                      for (final day in _days) {
                        _openingHours[day['key']!] = {
                          'open': '00:00',
                          'close': '23:30',
                          'isClosed': false,
                        };
                      }
                    });
                  },
                ),

                ActionChip(
                  avatar: const Icon(Icons.close, size: 16),
                  label: const Text('Closed All Week'),
                  onPressed: () {
                    setState(() {
                      for (final day in _days) {
                        _openingHours[day['key']!] = {
                          'open': '10:00',
                          'close': '22:00',
                          'isClosed': true,
                        };
                      }
                    });
                  },
                ),

                ActionChip(
                  avatar: const Icon(Icons.refresh, size: 16),
                  label: const Text('Reset Defaults'),
                  onPressed: () {
                    setState(() {
                      _openingHours = RestaurantService.getDefaultOpeningHours();
                    });
                  },
                ),
              ],
            ),
          ],
        ),
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
        title: const Text('Restaurant Opening Hours'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 0,
              color: Colors.blue[50],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.info, color: Colors.blue),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Set your restaurant hours',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Customers will only see your surplus listings during these hours.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            _buildQuickPresets(),

            const Text(
              'Daily Schedule',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'Set opening and closing times for each day:',
              style: TextStyle(color: Colors.grey),
            ),

            const SizedBox(height: 16),

            ..._days.map((day) => _buildDayCard(day)).toList(),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveOpeningHours,
                icon: _isSaving
                    ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Icon(Icons.save),
                label: Text(_isSaving ? 'Saving...' : 'Save Opening Hours'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.deepOrange,
                  foregroundColor: Colors.white,
                ),
              ),
            ),

            const SizedBox(height: 16),

            Card(
              elevation: 1,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Preview',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),

                    ..._days.map((day) {
                      final dayData = _openingHours[day['key']] as Map<String, dynamic>?;
                      final isClosed = dayData?['isClosed'] ?? false;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 100,
                              child: Text(
                                day['name']!,
                                style: const TextStyle(fontWeight: FontWeight.w500),
                              ),
                            ),
                            Text(
                              isClosed
                                  ? 'Closed'
                                  : '${dayData?['open'] ?? '10:00'} - ${dayData?['close'] ?? '22:00'}',
                              style: TextStyle(
                                color: isClosed ? Colors.grey : Colors.black,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}