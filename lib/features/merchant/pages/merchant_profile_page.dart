import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fyp_savr/data/services/firebase_service.dart';
import 'package:fyp_savr/data/services/restaurant_service.dart';
import 'package:fyp_savr/data/services/food_service.dart';
import 'package:fyp_savr/features/merchant/pages/restaurant_settings_page.dart';
import 'package:fyp_savr/utils/helpers.dart';
import 'package:fyp_savr/features/merchant/pages/add_food_item_page.dart';
import 'package:firebase_auth/firebase_auth.dart';


class MerchantProfilePage extends StatefulWidget {
  const MerchantProfilePage({super.key});

  @override
  State<MerchantProfilePage> createState() => _MerchantProfilePageState();
}

class _MerchantProfilePageState extends State<MerchantProfilePage> {
  Map<String, dynamic>? _restaurantData;
  Map<String, dynamic>? _foodStats;
  bool _isLoading = true;
  bool _isEditing = false;

  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadRestaurantData();
    _loadFoodStats();
  }

  Future<void> _loadRestaurantData() async {
    try {
      final user = FirebaseService.auth.currentUser;
      if (user != null) {
        final restaurantDoc = await FirebaseService.restaurants.doc(user.uid).get();
        if (restaurantDoc.exists) {
          setState(() {
            _restaurantData = {
              'id': restaurantDoc.id,
              ...restaurantDoc.data() as Map<String, dynamic>,
            };
            _initializeControllers();
          });
        }
      }
    } catch (e) {
      print('Error loading restaurant data: $e');
    }
  }

  Future<void> _loadFoodStats() async {
    try {
      final user = FirebaseService.auth.currentUser;
      if (user != null) {
        final stats = await FoodService.getFoodStats(user.uid);
        setState(() {
          _foodStats = stats;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading food stats: $e');
      setState(() => _isLoading = false);
    }
  }

  void _initializeControllers() {
    if (_restaurantData != null) {
      _nameController.text = _restaurantData!['name'] ?? '';
      _descriptionController.text = _restaurantData!['description'] ?? '';
      _phoneController.text = _restaurantData!['phone'] ?? '';
      _addressController.text = _restaurantData!['address'] ?? '';
    }
  }

  Future<void> _updateRestaurantProfile() async {
    if (_nameController.text.isEmpty || _phoneController.text.isEmpty || _addressController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all required fields')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseService.auth.currentUser!;

      await RestaurantService.updateRestaurant(user.uid, {
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'phone': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        'updatedAt': DateTime.now(),
      });

      await _loadRestaurantData();

      setState(() => _isEditing = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating profile: ${e.toString()}')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateDeliveryTime() async {
    final currentDeliveryTime = _restaurantData?['deliveryTime'] ?? '20-30 min';
    String currentValue = currentDeliveryTime.replaceAll(' min', '');

    String? selectedValue = currentValue;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Set Estimated Pickup Time'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Select pickup time range:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    '10-15', '15-20', '20-25', '25-30',
                    '30-35', '35-40', '40-45', '45-50',
                    '50-55', '55-60', '60-75', '75-90'
                  ].map((time) {
                    final isSelected = selectedValue == time;
                    return ChoiceChip(
                      label: Text('$time min'),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => selectedValue = time);
                        }
                      },
                      selectedColor: Colors.deepOrange,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : Colors.black,
                        fontWeight: FontWeight.w500,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Note: This is the estimated preparation time customers will see',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: selectedValue != null
                    ? () async {
                  try {
                    final restaurantId = FirebaseService.auth.currentUser!.uid;
                    final formattedTime = '$selectedValue min';

                    await RestaurantService.updateRestaurant(restaurantId, {
                      'deliveryTime': formattedTime,
                      'updatedAt': DateTime.now(),
                    });

                    if (mounted) {
                      setState(() {
                        _restaurantData?['deliveryTime'] = formattedTime;
                      });

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Pickup time updated to $formattedTime'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error: ${e.toString()}'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                  if (mounted) Navigator.pop(context);
                }
                    : null,
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showFAQs() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.help_outline, color: Colors.deepOrange),
            SizedBox(width: 8),
            Text('FAQ & Regulations'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Important Guidelines for Restaurant Partners:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 16),

              _buildFAQItem(
                '1. Food Quality & Safety',
                '• All surplus food must be safe for consumption\n• Maintain proper temperature control\n• Follow food handling best practices',
              ),

              _buildFAQItem(
                '2. Listing Requirements',
                '• Clearly state food items and quantities\n• Include accurate expiration/pickup times\n• Provide proper food descriptions\n• Set realistic pickup windows',
              ),

              _buildFAQItem(
                '3. Order Fulfillment',
                '• Confirm orders promptly\n• Prepare food within stated pickup time\n• Verify customer orders during pickup\n• Update order status in real-time',
              ),

              _buildFAQItem(
                '4. Pricing Guidelines',
                '• Follow dynamic pricing suggestions\n• Set fair discount prices (30-70% off)\n• Be transparent about original vs. discounted prices',
              ),

              _buildFAQItem(
                '5. Customer Communication',
                '• Respond to customer inquiries promptly\n• Notify customers of any changes\n• Handle issues professionally',
              ),

              _buildFAQItem(
                '6. Account Management',
                '• Keep restaurant information updated\n• Maintain accurate opening hours\n• Update pickup time as needed',
              ),

              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Need Help? Contact Admin:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.deepOrange,
                      ),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      child: Row(
                        children: [
                          const Icon(Icons.email, size: 16, color: Colors.deepOrange),
                          const SizedBox(width: 8),
                          SelectableText(
                            'savradminmy@gmail.com',
                            style: const TextStyle(
                              color: Colors.deepOrange,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'For account issues, listing questions, or partnership inquiries',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
        scrollable: true,
      ),
    );
  }

  Widget _buildFAQItem(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.deepOrange,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            content,
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    try {
      final bool? confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Logout'),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Logout', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );

      if (confirm == true) {
        await FirebaseAuth.instance.signOut();

        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/',
                (route) => false,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error logging out: ${e.toString()}')),
        );
      }
    }
  }

  Widget _buildStatsCard() {
    if (_foodStats == null) return const SizedBox();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              'Business Overview',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              children: [
                _StatItem(
                  title: 'Active Listings',
                  value: _foodStats!['activeCount'].toString(),
                  color: Colors.green,
                  icon: Icons.fastfood,
                ),
                _StatItem(
                  title: 'Total Listings',
                  value: _foodStats!['totalCount'].toString(),
                  color: Colors.blue,
                  icon: Icons.inventory,
                ),
                _StatItem(
                  title: 'Expiring Soon',
                  value: _foodStats!['expiringSoonCount'].toString(),
                  color: Colors.orange,
                  icon: Icons.timer,
                ),
                _StatItem(
                  title: 'Total Value',
                  value: Helpers.formatCurrency((_foodStats!['totalValue'] ?? 0).toDouble()),
                  color: Colors.purple,
                  icon: Icons.attach_money,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVerificationStatus() {
    if (_restaurantData == null) return const SizedBox();

    final status = _restaurantData!['verificationStatus'] ?? 'pending';
    Color statusColor;
    String statusText;

    switch (status) {
      case 'approved':
        statusColor = Colors.green;
        statusText = 'Verified ✓';
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusText = 'Rejected';
        break;
      default:
        statusColor = Colors.orange;
        statusText = 'Pending Review';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              status == 'approved' ? Icons.verified : Icons.pending,
              color: statusColor,
              size: 40,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                  if (_restaurantData!['adminNotes'] != null && _restaurantData!['adminNotes'].isNotEmpty)
                    Text(
                      'Note: ${_restaurantData!['adminNotes']}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  if (status == 'pending')
                    const Text(
                      'Your documents are under review',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileForm() {
    if (_restaurantData == null) return const SizedBox();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Restaurant Information',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (!_isEditing)
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () => setState(() => _isEditing = true),
                    tooltip: 'Edit Profile',
                  ),
              ],
            ),
            const SizedBox(height: 16),

            if (_isEditing) ...[
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Restaurant Name *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number *',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: 'Address *',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() => _isEditing = false);
                        _initializeControllers();
                      },
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _updateRestaurantProfile,
                      child: const Text('Save Changes'),
                    ),
                  ),
                ],
              ),
            ] else ...[
              _ProfileField(
                label: 'Restaurant Name',
                value: _restaurantData!['name'] ?? 'Not set',
              ),
              _ProfileField(
                label: 'Description',
                value: _restaurantData!['description'] ?? 'No description',
              ),
              _ProfileField(
                label: 'Phone',
                value: _restaurantData!['phone'] ?? 'Not set',
              ),
              _ProfileField(
                label: 'Address',
                value: _restaurantData!['address'] ?? 'Not set',
              ),
              _ProfileField(
                label: 'Cuisine Types',
                value: (_restaurantData!['cuisineTypes'] as List?)?.join(', ') ?? 'Not set',
              ),
              _ProfileField(
                label: 'Joined Date',
                value: _restaurantData!['createdAt'] != null
                    ? Helpers.formatDate((_restaurantData!['createdAt'] as Timestamp).toDate())
                    : 'Unknown',
              ),
            ],
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
        title: const Text('Merchant Profile'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.deepOrange[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.restaurant, size: 40, color: Colors.deepOrange),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _restaurantData?['name'] ?? 'Your Restaurant',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _restaurantData?['cuisineTypes']?.join(', ') ?? 'Restaurant',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.star, color: Colors.amber, size: 16),
                              const SizedBox(width: 4),
                              Text('${(_restaurantData?['rating'] ?? 0.0).toStringAsFixed(2)}'),
                              const SizedBox(width: 16),
                              Icon(Icons.reviews, color: Colors.grey, size: 16),
                              const SizedBox(width: 4),
                              Text('${_restaurantData?['totalReviews'] ?? 0} reviews'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            _buildVerificationStatus(),
            const SizedBox(height: 16),

            _buildStatsCard(),
            const SizedBox(height: 16),

            _buildProfileForm(),
            const SizedBox(height: 16),

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
                          avatar: const Icon(Icons.add, size: 16),
                          label: const Text('Add New Food'),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const AddFoodItemPage()),
                            );
                          },
                        ),
                        ActionChip(
                          avatar: const Icon(Icons.settings, size: 16),
                          label: const Text('Change Opening Hours'),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const RestaurantSettingsPage()),
                            );
                          },
                        ),
                        ActionChip(
                          avatar: const Icon(Icons.timer, size: 16),
                          label: const Text('Set Pickup Time'),
                          onPressed: _updateDeliveryTime,
                        ),
                        ActionChip(
                          avatar: const Icon(Icons.help_outline, size: 16),
                          label: const Text('FAQ & Regulations'),
                          onPressed: () {
                            _showFAQs();
                          },
                        ),
                        // logout
                        ActionChip(
                          avatar: const Icon(Icons.logout, size: 16, color: Colors.red),
                          label: const Text('Logout', style: TextStyle(color: Colors.red)),
                          backgroundColor: Colors.red[50],
                          onPressed: _logout,
                        ),
                      ],
                    ),
                    if (_restaurantData?['deliveryTime'] != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Text(
                          'Current pickup time: ${_restaurantData?['deliveryTime']}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
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
}

class _StatItem extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  final IconData icon;

  const _StatItem({
    required this.title,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
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

class _ProfileField extends StatelessWidget {
  final String label;
  final String value;

  const _ProfileField({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}