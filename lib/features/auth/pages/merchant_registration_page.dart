import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:fyp_savr/data/services/firebase_service.dart';
import 'package:fyp_savr/data/services/restaurant_service.dart';
import 'package:fyp_savr/utils/constants.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MerchantRegistrationPage extends StatefulWidget {
  const MerchantRegistrationPage({super.key});

  @override
  State<MerchantRegistrationPage> createState() => _MerchantRegistrationPageState();
}

class _MerchantRegistrationPageState extends State<MerchantRegistrationPage> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _restaurantNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _descriptionController = TextEditingController();

  final _businessRegistrationUrlController = TextEditingController();
  final _ownerIdUrlController = TextEditingController();
  final _healthPermitUrlController = TextEditingController();
  final _restaurantPhotoUrlController = TextEditingController();

  bool _isLoading = false;
  bool _passwordVisible = false;
  bool _confirmPasswordVisible = false;
  int _currentStep = 0;
  List<String> _selectedCuisines = [];

  LatLng _selectedLocation = const LatLng(3.1390, 101.6869); // Default KL
  bool _hasSelectedLocation = false;

  late AnimationController _stepController;
  late Animation<double> _stepAnimation;

  final List<String> _cuisineOptions = [
    'Italian', 'Chinese', 'Japanese', 'Mexican', 'Indian',
    'Thai', 'Korean', 'Vietnamese', 'Malaysian', 'Western',
    'Fast Food', 'Vegetarian', 'Vegan', 'Halal', 'Desserts',
    'Beverages', 'Fusion', 'Street Food', 'Fine Dining', 'Café'
  ];

  @override
  void initState() {
    super.initState();
    _stepController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _stepAnimation = CurvedAnimation(
      parent: _stepController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _stepController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _restaurantNameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _descriptionController.dispose();
    _businessRegistrationUrlController.dispose();
    _ownerIdUrlController.dispose();
    _healthPermitUrlController.dispose();
    _restaurantPhotoUrlController.dispose();
    super.dispose();
  }

  bool _isValidGoogleDriveUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;

    return uri.host.contains('drive.google.com') ||
        uri.host.contains('docs.google.com');
  }

  Future<void> _pickLocation() async {
    final LatLng? pickedLocation = await showDialog<LatLng>(
      context: context,
      builder: (context) => LocationPickerDialog(
        initialLocation: _selectedLocation,
      ),
    );

    if (pickedLocation != null) {
      setState(() {
        _selectedLocation = pickedLocation;
        _hasSelectedLocation = true;
      });
    }
  }

  Future<void> _nextStep() async {
    if (_currentStep == 0 && !_validateStep1()) return;
    if (_currentStep == 1 && !_validateStep2()) return;

    await _stepController.reverse();
    setState(() => _currentStep++);
    _stepController.forward();
  }

  void _previousStep() {
    _stepController.reverse().then((_) {
      setState(() => _currentStep--);
      _stepController.forward();
    });
  }

  bool _validateStep1() {
    final nameValid = _nameController.text.trim().isNotEmpty;
    final emailValid = _emailController.text.trim().isNotEmpty &&
        RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(_emailController.text.trim());
    final passwordValid = _passwordController.text.length >= 8
        && _passwordController.text.contains(RegExp(r'[A-Z]'))
        && _passwordController.text.contains(RegExp(r'[a-z]'))
        && _passwordController.text.contains(RegExp(r'[0-9]'));
    final passwordsMatch = _passwordController.text == _confirmPasswordController.text;

    if (!nameValid) {
      _showError('Full name is required');
      return false;
    }
    if (!emailValid) {
      _showError('Please enter a valid email address');
      return false;
    }
    if (!passwordValid) {
      _showError('Password must be at least 8 characters with uppercase, lowercase, and numbers');
      return false;
    }
    if (!passwordsMatch) {
      _showError('Passwords do not match');
      return false;
    }

    return true;
  }

  bool _validateStep2() {
    if (_restaurantNameController.text.trim().isEmpty) {
      _showError('Restaurant name is required');
      return false;
    }

    if (_phoneController.text.trim().isEmpty) {
      _showError('Phone number is required');
      return false;
    }

    if (_addressController.text.trim().isEmpty) {
      _showError('Address is required');
      return false;
    }

    if (_selectedCuisines.isEmpty) {
      _showError('Please select at least one cuisine type');
      return false;
    }

    if (!_hasSelectedLocation) {
      _showError('Please select your restaurant location on the map');
      return false;
    }

    if (_businessRegistrationUrlController.text.isEmpty) {
      _showError('Business Registration Google Drive link is required');
      return false;
    }

    if (!_isValidGoogleDriveUrl(_businessRegistrationUrlController.text)) {
      _showError('Please provide a valid Google Drive URL for Business Registration (SSM)');
      return false;
    }

    if (_ownerIdUrlController.text.isEmpty) {
      _showError('Owner Identification Google Drive link is required');
      return false;
    }

    if (!_isValidGoogleDriveUrl(_ownerIdUrlController.text)) {
      _showError('Please provide a valid Google Drive URL for Owner ID');
      return false;
    }

    if (_healthPermitUrlController.text.isEmpty) {
      _showError('Registered License Google Drive link is required');
      return false;
    }

    if (!_isValidGoogleDriveUrl(_healthPermitUrlController.text)) {
      _showError('Please provide a valid Google Drive URL for Registered License');
      return false;
    }

    if (_restaurantPhotoUrlController.text.isEmpty) {
      _showError('Restaurant Photo Google Drive link is required');
      return false;
    }

    if (!_isValidGoogleDriveUrl(_restaurantPhotoUrlController.text)) {
      _showError('Please provide a valid Google Drive URL for Restaurant Photo');
      return false;
    }

    return true;
  }

  Future<void> _completeRegistration() async {
    if (!_validateStep1() || !_validateStep2()) {
      _showError('Please complete all required fields');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      final user = userCredential.user!;

      await user.updateDisplayName(_nameController.text.trim());

      final restaurantId = await RestaurantService.createRestaurant(
        merchantId: user.uid,
        name: _restaurantNameController.text.trim(),
        description: _descriptionController.text.trim().isNotEmpty
            ? _descriptionController.text.trim()
            : 'Quality food at discounted prices',
        address: _addressController.text.trim(),
        phone: _phoneController.text.trim(),
        latitude: _selectedLocation.latitude,
        longitude: _selectedLocation.longitude,
        cuisineTypes: _selectedCuisines,
        documents: _getDocumentUrls(),
        verificationStatus: AppConstants.statusPending,
        logoBase64: null,
        coverImageBase64: null,
      );

      await FirebaseService.users.doc(user.uid).set({
        'uid': user.uid,
        'restaurantId': user.uid,
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'role': AppConstants.roleMerchant,
        'phone': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        'restaurantName': _restaurantNameController.text.trim(),
        'verificationStatus': AppConstants.statusPending,
        'isEmailVerified': true,
        'profileImageUrl': '',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      _showSuccess('Registration successful! Verification pending.');
      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {
        Navigator.pop(context);
      }

    } on FirebaseAuthException catch (e) {
      _handleAuthError(e);
    } catch (e) {
      _showError('Registration failed: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Map<String, dynamic> _getDocumentUrls() {
    return {
      'businessRegistration': _businessRegistrationUrlController.text.trim(),
      'ownerId': _ownerIdUrlController.text.trim(),
      'healthPermit': _healthPermitUrlController.text.trim(),
      'restaurantPhoto': _restaurantPhotoUrlController.text.trim(),
    };
  }

  void _handleAuthError(FirebaseAuthException e) {
    String message;
    switch (e.code) {
      case 'email-already-in-use':
        message = 'This email is already registered. Please use a different email or try logging in.';
        break;
      case 'invalid-email':
        message = 'The email address is invalid. Please check and try again.';
        break;
      case 'operation-not-allowed':
        message = 'Email/password accounts are not enabled. Please contact support.';
        break;
      case 'weak-password':
        message = 'Password is too weak. Please use at least 8 characters with letters and numbers.';
        break;
      default:
        message = 'Registration failed: ${e.message}';
    }
    _showError(message);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Merchant Registration'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildProgressIndicator(),

            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 500),
                child: _buildStepContent(),
              ),
            ),

            _buildNavigationButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(3, (index) {
              return Column(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _currentStep >= index ? Colors.green : Colors.grey[300],
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: _currentStep > index
                          ? const Icon(Icons.check, color: Colors.white, size: 20)
                          : Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: _currentStep >= index ? Colors.white : Colors.grey[600],
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    ['Basic Info', 'Business Details', 'Review'][index],
                    style: TextStyle(
                      fontWeight: _currentStep == index ? FontWeight.bold : FontWeight.normal,
                      color: _currentStep >= index ? Colors.green : Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              );
            }),
          ),

          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: (_currentStep + 1) / 3,
            backgroundColor: Colors.grey[200],
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
            minHeight: 4,
            borderRadius: BorderRadius.circular(2),
          ),
        ],
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0: return _buildStep1BasicInfo();
      case 1: return _buildStep2BusinessDetails();
      case 2: return _buildStep3Review();
      default: return const SizedBox();
    }
  }

  Widget _buildStep1BasicInfo() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(
              title: 'Account Information',
              subtitle: 'Create your merchant account',
            ),
            const SizedBox(height: 24),

            _buildTextField(
              controller: _nameController,
              label: 'Full Name',
              hint: 'Enter your full name',
              icon: Icons.person_outlined,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]')), // Only letters and spaces
                LengthLimitingTextInputFormatter(100),
              ],
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Full name is required';
                }

                final trimmedValue = value.trim();

                if (trimmedValue.length < 2) {
                  return 'Name must be at least 2 characters';
                }

                if (!trimmedValue.contains(' ')) {
                  return 'Please enter your full name (first and last)';
                }

                // Check for numbers
                if (RegExp(r'\d').hasMatch(trimmedValue)) {
                  return 'Name should not contain numbers';
                }

                return null;
              },
            ),
            const SizedBox(height: 16),

            _buildTextField(
              controller: _emailController,
              label: 'Email Address',
              hint: 'you@restaurant.com',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value!.isEmpty) return 'Required';
                if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                  return 'Invalid email';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            _buildPasswordField(
              controller: _passwordController,
              label: 'Password',
              isVisible: _passwordVisible,
              onToggleVisibility: () => setState(() => _passwordVisible = !_passwordVisible),
              validator: (value) {
                if (value!.isEmpty) return 'Required';
                if (value.length < 8) return 'Minimum 8 characters';
                if (!value.contains(RegExp(r'[A-Z]'))) return 'Add uppercase letter';
                if (!value.contains(RegExp(r'[a-z]'))) return 'Add lowercase letter';
                if (!value.contains(RegExp(r'[0-9]'))) return 'Add a number';
                return null;
              },
            ),
            const SizedBox(height: 16),

            _buildPasswordField(
              controller: _confirmPasswordController,
              label: 'Confirm Password',
              isVisible: _confirmPasswordVisible,
              onToggleVisibility: () => setState(() => _confirmPasswordVisible = !_confirmPasswordVisible),
              validator: (value) {
                if (value!.isEmpty) return 'Required';
                if (value != _passwordController.text) return 'Passwords do not match';
                return null;
              },
            ),

            _buildInfoBox(
              title: 'Password Requirements:',
              points: [
                'Minimum 8 characters',
                'At least one uppercase letter',
                'At least one lowercase letter',
                'At least one number',
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep2BusinessDetails() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            title: 'Business Details',
            subtitle: 'Tell us about your restaurant',
          ),
          const SizedBox(height: 24),

          _buildTextField(
            controller: _restaurantNameController,
            label: 'Restaurant Name',
            hint: 'Enter restaurant name',
            icon: Icons.restaurant_outlined,
            validator: (value) => value!.isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 16),

          _buildTextField(
            controller: _phoneController,
            label: 'Phone Number',
            hint: '+60 12 345 6789',
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Phone number is required';
              }

              final cleanedPhone = value.replaceAll(RegExp(r'[^\d+]'), '');

              final phoneRegex = RegExp(r'^(\+?6?01)[0-46-9]-?[0-9]{7,8}$');

              if (!phoneRegex.hasMatch(cleanedPhone)) {
                return 'Please enter a valid Malaysian phone number\nFormat: +60 12 345 6789 or 012-345 6789';
              }

              return null;
            },
          ),
          const SizedBox(height: 16),

          _buildTextField(
            controller: _addressController,
            label: 'Restaurant Address',
            hint: 'Full address including city and postal code',
            icon: Icons.location_on_outlined,
            maxLines: 2,
            validator: (value) => value!.isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(12),
              color: _hasSelectedLocation ? Colors.green[50] : Colors.white,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      color: _hasSelectedLocation ? Colors.green : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Restaurant Location',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  _hasSelectedLocation
                      ? 'Location selected: ${_selectedLocation.latitude.toStringAsFixed(4)}, ${_selectedLocation.longitude.toStringAsFixed(4)}'
                      : 'Default location: Kuala Lumpur (3.1390, 101.6869)',
                  style: TextStyle(
                    color: _hasSelectedLocation ? Colors.green[800] : Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: _pickLocation,
                  icon: const Icon(Icons.map),
                  label: const Text('Pick Location on Map'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _hasSelectedLocation ? Colors.green : Colors.blue,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 48),
                  ),
                ),
                if (!_hasSelectedLocation)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'Click above to select your exact restaurant location',
                      style: TextStyle(fontSize: 12, color: Colors.orange),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          _buildTextField(
            controller: _descriptionController,
            label: 'Description',
            hint: 'Tell customers about your restaurant...',
            icon: Icons.description_outlined,
            maxLines: 3,
          ),
          const SizedBox(height: 24),

          _buildSectionHeader(
            title: 'Cuisine Types',
            subtitle: 'Select all that apply',
          ),
          const SizedBox(height: 16),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _cuisineOptions.map((cuisine) {
              final isSelected = _selectedCuisines.contains(cuisine);
              return FilterChip(
                label: Text(cuisine),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedCuisines.add(cuisine);
                    } else {
                      _selectedCuisines.remove(cuisine);
                    }
                  });
                },
                backgroundColor: Colors.grey[200],
                selectedColor: Colors.green[100],
                checkmarkColor: Colors.green,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.green[800] : Colors.grey[800],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 32),

          _buildGoogleDriveInstructions(),
          const SizedBox(height: 16),

          _buildSectionHeader(
            title: 'Required Documents (Google Drive Links)',
            subtitle: 'Share your documents via Google Drive and paste the links',
          ),
          const SizedBox(height: 16),

          _buildDocumentUrlField(
            title: 'Business Registration (SSM)',
            description: 'SSM, ROC, or equivalent Business Registration document',
            controller: _businessRegistrationUrlController,
            isRequired: true,
            hintText: 'https://drive.google.com/file/d/...',
          ),
          const SizedBox(height: 12),

          _buildDocumentUrlField(
            title: 'Owner Identification',
            description: 'NRIC, passport, or driver\'s license of business owner',
            controller: _ownerIdUrlController,
            isRequired: true,
            hintText: 'https://drive.google.com/file/d/...',
          ),
          const SizedBox(height: 12),

          _buildDocumentUrlField(
            title: 'Registered License',
            description: 'Food establishment license or Registered License',
            controller: _healthPermitUrlController,
            isRequired: true,
            hintText: 'https://drive.google.com/file/d/...',
          ),
          const SizedBox(height: 12),

          _buildDocumentUrlField(
            title: 'Restaurant Photo',
            description: 'Photo of your restaurant front or interior',
            controller: _restaurantPhotoUrlController,
            isRequired: true,
            hintText: 'https://drive.google.com/file/d/...',
          ),
        ],
      ),
    );
  }

  Widget _buildStep3Review() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            title: 'Review & Submit',
            subtitle: 'Confirm your information before submitting',
          ),
          const SizedBox(height: 24),

          _buildReviewSection(
            title: 'Account Information',
            items: [
              _buildReviewItem('Full Name', _nameController.text),
              _buildReviewItem('Email', _emailController.text),
            ],
          ),
          const SizedBox(height: 24),

          _buildReviewSection(
            title: 'Business Information',
            items: [
              _buildReviewItem('Restaurant Name', _restaurantNameController.text),
              _buildReviewItem('Phone', _phoneController.text),
              _buildReviewItem('Address', _addressController.text),
              _buildReviewItem('Location Coordinates',
                  '${_selectedLocation.latitude.toStringAsFixed(6)}, '
                      '${_selectedLocation.longitude.toStringAsFixed(6)}'),
              if (_descriptionController.text.isNotEmpty)
                _buildReviewItem('Description', _descriptionController.text),
              _buildReviewItem('Cuisine Types', _selectedCuisines.join(', ')),
            ],
          ),
          const SizedBox(height: 24),

          _buildReviewSection(
            title: 'Document Links',
            items: [
              if (_businessRegistrationUrlController.text.isNotEmpty)
                _buildReviewItem('Business Registration (SSM)',
                    _businessRegistrationUrlController.text),
              if (_ownerIdUrlController.text.isNotEmpty)
                _buildReviewItem('Owner ID', _ownerIdUrlController.text),
              if (_healthPermitUrlController.text.isNotEmpty)
                _buildReviewItem('Registered License', _healthPermitUrlController.text),
              if (_restaurantPhotoUrlController.text.isNotEmpty)
                _buildReviewItem('Restaurant Photo', _restaurantPhotoUrlController.text),
            ],
          ),
          const SizedBox(height: 32),

          Card(
            elevation: 0,
            color: Colors.blue[50],
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Terms & Conditions',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'By submitting this application, you agree to:\n'
                        '• Provide accurate information\n'
                        '• Maintain food safety standards\n'
                        '• Fulfill orders promptly\n'
                        '• Accept our commission structure\n'
                        '• Respond to customer inquiries within 24 hours',
                    style: TextStyle(fontSize: 14, color: Colors.blue),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Verification may take 2-3 business days',
                          style: TextStyle(fontSize: 13, color: Colors.blue[700]),
                        ),
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

  Widget _buildNavigationButtons() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: _isLoading ? null : _previousStep,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(color: Colors.grey[300]!),
                ),
                child: const Text('Back'),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 12),
          Expanded(
            flex: _currentStep == 2 ? 1 : 2,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _currentStep == 2 ? _completeRegistration : _nextStep,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.green,
              ),
              child: _isLoading
                  ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
                  : Text(
                _currentStep == 2 ? 'Submit Application' : 'Continue',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({required String title, required String subtitle}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: Colors.grey[600]),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.green, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool isVisible,
    required VoidCallback onToggleVisibility,
    required String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: !isVisible,
          validator: validator,
          decoration: InputDecoration(
            hintText: 'Enter password',
            prefixIcon: Icon(Icons.lock_outline, color: Colors.grey[600]),
            suffixIcon: IconButton(
              icon: Icon(
                isVisible ? Icons.visibility_off : Icons.visibility,
                color: Colors.grey[600],
              ),
              onPressed: onToggleVisibility,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.green, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoBox({required String title, required List<String> points}) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[100]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.blue[800],
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          ...points.map((point) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('• ', style: TextStyle(color: Colors.blue)),
                Expanded(
                  child: Text(
                    point,
                    style: TextStyle(color: Colors.blue[700], fontSize: 13),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildDocumentUrlField({
    required String title,
    required String description,
    required TextEditingController controller,
    required bool isRequired,
    String? hintText,
  }) {
    final hasValidUrl = controller.text.isNotEmpty &&
        _isValidGoogleDriveUrl(controller.text);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: hasValidUrl ? Colors.green[300]! : Colors.grey[200]!,
          width: hasValidUrl ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.link,
                  color: hasValidUrl ? Colors.green : Colors.grey,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          if (isRequired)
                            const Padding(
                              padding: EdgeInsets.only(left: 4),
                              child: Text(
                                '*',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        description,
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: controller,
              decoration: InputDecoration(
                hintText: hintText ?? 'Paste Google Drive link here...',
                prefixIcon: const Icon(Icons.drive_folder_upload),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                suffixIcon: controller.text.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear, size: 20),
                  onPressed: () {
                    controller.clear();
                    setState(() {});
                  },
                )
                    : null,
              ),
              keyboardType: TextInputType.url,
              onChanged: (value) {
                setState(() {});
              },
            ),
            if (controller.text.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Icon(
                      hasValidUrl ? Icons.check_circle : Icons.warning,
                      color: hasValidUrl ? Colors.green[600] : Colors.orange,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      hasValidUrl ? 'Valid Google Drive link' : 'Invalid or non-Google Drive link',
                      style: TextStyle(
                        color: hasValidUrl ? Colors.green[600] : Colors.orange,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoogleDriveInstructions() {
    return ExpansionTile(
      initiallyExpanded: true,
      title: const Text('📚 How to share Google Drive links'),
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInstructionStep(1, 'Upload your document to Google Drive'),
              _buildInstructionStep(2, 'Right-click on the file and select "Share"'),
              _buildInstructionStep(3, 'Click "Change" next to "Restricted"'),
              _buildInstructionStep(4, 'Select "Anyone with the link"'),
              _buildInstructionStep(5, 'Click "Copy link" and paste it below'),
              const SizedBox(height: 16),
              const Text(
                'Note: Make sure the link is publicly accessible for verification.',
                style: TextStyle(fontSize: 12, color: Colors.orange),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInstructionStep(int number, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                '$number',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  Widget _buildReviewSection({required String title, required List<Widget> items}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 0,
          color: Colors.grey[50],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: items,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReviewItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value.isEmpty ? 'Not provided' : value,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                if (value.contains('drive.google.com'))
                  const Text(
                    'Google Drive Link',
                    style: TextStyle(fontSize: 12, color: Colors.blue),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class LocationPickerDialog extends StatefulWidget {
  final LatLng initialLocation;

  const LocationPickerDialog({super.key, required this.initialLocation});

  @override
  State<LocationPickerDialog> createState() => _LocationPickerDialogState();
}

class _LocationPickerDialogState extends State<LocationPickerDialog> {
  late GoogleMapController _mapController;
  LatLng _selectedLocation = const LatLng(3.1390, 101.6869);
  Marker? _marker;

  @override
  void initState() {
    super.initState();
    _selectedLocation = widget.initialLocation;
    _marker = Marker(
      markerId: const MarkerId('selected'),
      position: _selectedLocation,
      draggable: true,
      onDragEnd: (LatLng newPosition) {
        setState(() {
          _selectedLocation = newPosition;
          _marker = _marker!.copyWith(
            positionParam: newPosition,
          );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Restaurant Location'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: Column(
          children: [
            Expanded(
              child: GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: _selectedLocation,
                  zoom: 14,
                ),
                onMapCreated: (controller) {
                  _mapController = controller;
                },
                markers: _marker != null ? {_marker!} : {},
                onTap: (LatLng location) {
                  setState(() {
                    _selectedLocation = location;
                    _marker = Marker(
                      markerId: const MarkerId('selected'),
                      position: location,
                      draggable: true,
                      onDragEnd: (LatLng newPosition) {
                        setState(() {
                          _selectedLocation = newPosition;
                        });
                      },
                    );
                  });
                },
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Lat: ${_selectedLocation.latitude.toStringAsFixed(6)}, '
                  'Lng: ${_selectedLocation.longitude.toStringAsFixed(6)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              'Tap on map to select location or drag the marker',
              style: TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _selectedLocation),
          child: const Text('Select Location'),
        ),
      ],
    );
  }
}