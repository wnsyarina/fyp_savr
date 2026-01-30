import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fyp_savr/data/services/firebase_service.dart';
import 'package:fyp_savr/features/auth/pages/landing_page.dart';
import 'package:fyp_savr/features/customer/pages/payment_methods_page.dart';
import 'package:fyp_savr/features/customer/pages/customer_order_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userData = await FirebaseService.getUserProfile(user.uid);
        setState(() {
          _userData = userData;
          _nameController.text = userData?['name'] ?? 'No Name';
          _emailController.text = userData?['email'] ?? 'No Email';
          _addressController.text = userData?['address'] ?? 'No Address';
          _phoneController.text = userData?['phone'] ?? 'No Phone';
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Error loading user data: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateUserProfile() async {
    setState(() => _isSaving = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseService.updateUserProfile(
          uid: user.uid,
          updates: {
            'name': _nameController.text.trim(),
            'address': _addressController.text.trim(),
            'phone': _phoneController.text.trim(),
            'updatedAt': DateTime.now(),
          },
        );

        _showSuccessSnackbar('Profile updated successfully!');
        await _loadUserData();
      }
    } catch (e) {
      _showErrorSnackbar('Failed to update profile: ${e.toString()}');
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _showEditDialog({
    required String title,
    required TextEditingController controller,
    required String fieldName,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit $title'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: fieldName,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _updateUserProfile();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showPersonalInfoScreen() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Personal Information',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _buildEditableField(
                label: 'Full Name',
                value: _nameController.text,
                controller: _nameController,
                fieldName: 'Name',
              ),
              const SizedBox(height: 12),
              _buildEditableField(
                label: 'Email',
                value: _emailController.text,
                controller: _emailController,
                fieldName: 'Email',
                isEditable: false,
              ),
              const SizedBox(height: 12),
              _buildEditableField(
                label: 'Phone',
                value: _phoneController.text,
                controller: _phoneController,
                fieldName: 'Phone',
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _updateUserProfile,
                  child: _isSaving
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Text('Save Changes'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEditableField({
    required String label,
    required String value,
    required TextEditingController controller,
    required String fieldName,
    bool isEditable = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          enabled: isEditable,
          decoration: InputDecoration(
            hintText: 'Enter your $label',
            border: const OutlineInputBorder(),
            suffixIcon: isEditable
                ? IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => _showEditDialog(
                title: label,
                controller: controller,
                fieldName: fieldName,
              ),
            )
                : null,
          ),
        ),
      ],
    );
  }

  Future<void> _logout() async {
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
      try {
        print('Logging out...');
        await FirebaseAuth.instance.signOut();

        _showSuccessSnackbar('Logged out successfully!');

        if (mounted) {
          print('Navigating to LandingPage...');
          await Future.delayed(const Duration(milliseconds: 800));

          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => LandingPage()),
                (route) => false,
          );
        }
      } catch (e) {
        print('Logout error: $e');
        _showErrorSnackbar('Logout failed: ${e.toString()}');
      }
    } else {
      print('Logout cancelled by user');
    }
  }


  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Your Profile')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Profile'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.blue[100],
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person,
                  size: 50,
                  color: Colors.blue,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                _nameController.text,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(_emailController.text),
            ),
            const SizedBox(height: 24),
            const Text(
              'Account Settings',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Personal Information'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: _showPersonalInfoScreen,
            ),
            ListTile(
              leading: const Icon(Icons.location_on),
              title: const Text('Saved Address'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                _showEditDialog(
                  title: 'Address',
                  controller: _addressController,
                  fieldName: 'Address',
                );
              },
            ),
        ListTile(
          leading: const Icon(Icons.payment),
          title: const Text('Payment Methods'),
          trailing: const Icon(Icons.arrow_forward_ios),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const PaymentMethodsPage(),
              ),
            );
          },
        ),
            const SizedBox(height: 24),
            const Text(
              'Orders',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('Order History'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CustomerOrderHistoryPage(),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            Center(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                onPressed: _logout,
                child: const Text('Log Out'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}