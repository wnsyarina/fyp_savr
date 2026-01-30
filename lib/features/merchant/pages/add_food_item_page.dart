import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:fyp_savr/data/services/food_service.dart';
import 'package:fyp_savr/data/services/firebase_service.dart';
import 'package:fyp_savr/data/services/dynamic_pricing_service.dart';
import 'package:intl/intl.dart';
import 'package:fyp_savr/data/services/imgbb_service.dart';
import 'package:cached_network_image/cached_network_image.dart';

class AddFoodItemPage extends StatefulWidget {
  const AddFoodItemPage({super.key});

  @override
  State<AddFoodItemPage> createState() => _AddFoodItemPageState();
}

class _AddFoodItemPageState extends State<AddFoodItemPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _originalPriceController = TextEditingController();
  final _discountPriceController = TextEditingController();
  final _quantityController = TextEditingController();

  TimeOfDay _pickupStart = TimeOfDay(hour: 17, minute: 0);
  TimeOfDay _pickupEnd = TimeOfDay(hour: 19, minute: 0);
  DateTime? _expiryDateTime; // Add this
  File? _imageFile;
  bool _isLoading = false;
  bool _useAICategories = true;
  DateTime? _selectedExpiryDate;
  Map<String, dynamic>? _pricingSuggestions;
  bool _showPricingSuggestions = false;

  bool _isUploadingImage = false;
  double _uploadProgress = 0.0;
  String? _uploadedImageUrl;

  List<String> _suggestedCategories = [];
  List<String> _selectedCategories = [];
  Map<String, double> _confidenceScores = {};
  bool _isPredicting = false;

  final List<String> _availableCategories = [
    'sushi', 'pizza', 'burger', 'asian', 'dessert',
    'healthy', 'mexican', 'seafood', 'breakfast', 'beverages'
  ];

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_onFoodNameChanged);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _originalPriceController.dispose();
    _discountPriceController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  void _onFoodNameChanged() {
    if (_nameController.text.length > 2 && _useAICategories) {
      _predictCategories();
    }
  }

  Future<void> _predictCategories() async {
    if (_isPredicting) return;

    setState(() => _isPredicting = true);

    try {
      final suggestions = await FoodService.getAICategorySuggestions(
        foodName: _nameController.text,
        description: _descriptionController.text,
      );

      setState(() {
        _suggestedCategories = suggestions['suggestedCategories'] ?? [];
        _confidenceScores = suggestions['confidenceScores'] ?? {};

        if (_suggestedCategories.isNotEmpty && _selectedCategories.isEmpty) {
          _selectedCategories = [_suggestedCategories.first];
        }
      });
    } catch (e) {
      print('AI prediction error: $e');
    } finally {
      setState(() => _isPredicting = false);
    }
  }

  void _toggleCategory(String category) {
    setState(() {
      if (_selectedCategories.contains(category)) {
        _selectedCategories.remove(category);
      } else {
        _selectedCategories.add(category);
      }
    });
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 85,
    );

    if (image != null) {
      final imageFile = File(image.path);

      final fileSize = await imageFile.length();
      if (fileSize > 5 * 1024 * 1024) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image too large. Please use images under 5MB.')),
        );
        return;
      }

      setState(() {
        _isUploadingImage = true;
        _uploadProgress = 0.0;
        _imageFile = imageFile;
        _uploadedImageUrl = null;
      });

      try {
        final imageUrl = await ImgBBService.uploadImage(imageFile);

        if (imageUrl != null) {
          setState(() {
            _uploadedImageUrl = imageUrl;
            _isUploadingImage = false;
            _uploadProgress = 1.0;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Image uploaded successfully!')),
          );
        } else {
          setState(() {
            _isUploadingImage = false;
            _imageFile = null;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Image upload failed. Please try again.')),
          );
        }
      } catch (e) {
        setState(() => _isUploadingImage = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload error: $e')),
        );
      }
    }
  }

  Future<void> _submitFoodItem() async {
    if (_formKey.currentState!.validate()) {
      if (_uploadedImageUrl == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please upload a food image')),
        );
        return;
      }

      if (_expiryDateTime == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please set an expiry date')),
        );
        return;
      }

      if (_expiryDateTime!.isBefore(DateTime.now())) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Expiry date must be in the future')),
        );
        return;
      }

      if (_selectedCategories.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select at least one category')),
        );
        return;
      }

      setState(() => _isLoading = true);

      try {
        final user = FirebaseService.auth.currentUser!;

        final now = DateTime.now();
        final pickupStart = DateTime(
          now.year, now.month, now.day,
          _pickupStart.hour, _pickupStart.minute,
        );
        final pickupEnd = _expiryDateTime!;

        if (pickupEnd.isBefore(pickupStart)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Pickup end time must be after start time')),
          );
          setState(() => _isLoading = false);
          return;
        }

        await FoodService.addFoodItem(
          restaurantId: user.uid,
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
          originalPrice: double.parse(_originalPriceController.text),
          discountPrice: double.parse(_discountPriceController.text),
          quantityAvailable: int.parse(_quantityController.text),
          pickupStart: pickupStart,
          pickupEnd: pickupEnd,
          categories: _selectedCategories,
          imageUrl: _uploadedImageUrl!,
          useAICategories: _useAICategories,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Food item added successfully!')),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${e.toString()}')),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _selectTime(bool isStart) async {
    final initialTime = isStart ? _pickupStart : _pickupEnd;
    final selectedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );

    if (selectedTime != null) {
      setState(() {
        if (isStart) {
          _pickupStart = selectedTime;
        } else {
          _pickupEnd = selectedTime;
        }
      });
    }
  }

  Future<void> _selectExpiryDateTime() async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(hours: 2)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3)),
    );

    if (selectedDate != null) {
      final selectedTime = await showTimePicker(
        context: context,
        initialTime: _pickupEnd,
      );

      if (selectedTime != null) {
        setState(() {
          _expiryDateTime = DateTime(
            selectedDate.year,
            selectedDate.month,
            selectedDate.day,
            selectedTime.hour,
            selectedTime.minute,
          );
          _pickupEnd = selectedTime;

          _selectedExpiryDate = _expiryDateTime!;
        });
        _calculatePricingSuggestions();
      }
    }
  }

  void _calculatePricingSuggestions() {
    if (_originalPriceController.text.isNotEmpty && _selectedExpiryDate != null) {
      final originalPrice = double.tryParse(_originalPriceController.text);
      final quantity = int.tryParse(_quantityController.text) ?? 1;

      if (originalPrice != null && originalPrice > 0) {
        setState(() {
          _pricingSuggestions = DynamicPricingService.getPricingSuggestions(
            originalPrice: originalPrice,
            expiryTime: _selectedExpiryDate!,
            quantity: quantity,
          );
          _showPricingSuggestions = true;
        });
      }
    }
  }

  Widget _buildImageSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Food Image',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Upload your image',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            const SizedBox(height: 12),

            if (_isUploadingImage)
              Column(
                children: [
                  LinearProgressIndicator(
                    value: _uploadProgress,
                    backgroundColor: Colors.grey[200],
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                  ),
                  const SizedBox(height: 8),
                  const Text('Uploading image...', style: TextStyle(fontSize: 12)),
                ],
              )
            else
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 180,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: _uploadedImageUrl != null ? Colors.green : Colors.grey,
                      width: _uploadedImageUrl != null ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _uploadedImageUrl != null
                      ? CachedNetworkImage(
                    imageUrl: _uploadedImageUrl!,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Center(
                      child: CircularProgressIndicator(color: Colors.orange),
                    ),
                    errorWidget: (context, url, error) => _buildImagePlaceholder(),
                  )
                      : _imageFile != null
                      ? Image.file(_imageFile!, fit: BoxFit.cover)
                      : _buildImagePlaceholder(),
                ),
              ),

            if (_uploadedImageUrl != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green[600], size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '*Image hosted on ImgBB',
                      style: TextStyle(color: Colors.green[600], fontSize: 12),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 16),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: _uploadedImageUrl!));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Image URL copied!')),
                      );
                    },
                    tooltip: 'Copy URL',
                  ),
                ],
              ),
            ],

            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue[700], size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Images are uploaded and available.',
                    style: TextStyle(color: Colors.blue[700], fontSize: 11),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.camera_alt, size: 50, color: Colors.grey),
        SizedBox(height: 8),
        Text('Tap to upload food image'),
        SizedBox(height: 4),
        Text(
          'Max 5MB • JPG/PNG',
          style: TextStyle(fontSize: 10, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildCategorySection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Categories',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Switch(
                  value: _useAICategories,
                  onChanged: (value) {
                    setState(() => _useAICategories = value);
                    if (value) _predictCategories();
                  },
                ),
                const Text('AI Suggestions'),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _useAICategories
                  ? 'AI will suggest categories based on your food name and description'
                  : 'Manually select categories',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            const SizedBox(height: 12),

            if (_useAICategories && _suggestedCategories.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _suggestedCategories.map((category) {
                  final isSelected = _selectedCategories.contains(category);
                  final confidence = _confidenceScores[category] ?? 0.0;

                  return FilterChip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(category),
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _getConfidenceColor(confidence).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _getConfidenceText(confidence),
                            style: TextStyle(
                              fontSize: 10,
                              color: _getConfidenceColor(confidence),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    selected: isSelected,
                    onSelected: (selected) => _toggleCategory(category),
                    checkmarkColor: Colors.white,
                    selectedColor: Colors.deepOrange,
                  );
                }).toList(),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _availableCategories.map((category) {
                  return FilterChip(
                    label: Text(category),
                    selected: _selectedCategories.contains(category),
                    onSelected: (selected) => _toggleCategory(category),
                  );
                }).toList(),
              ),

            if (_isPredicting)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                    SizedBox(width: 8),
                    Text('AI is predicting categories...', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPricingSuggestions() {
    if (!_showPricingSuggestions || _pricingSuggestions == null) {
      return const SizedBox();
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome, color: Colors.orange),
                const SizedBox(width: 8),
                const Text(
                  'AI Pricing Suggestions',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => setState(() => _showPricingSuggestions = false),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _pricingSuggestions!['timeBasedSuggestion'] ?? '',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),

            // Sales Probability
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.trending_up, color: Colors.blue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Sales Probability',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${_pricingSuggestions!['salesProbability'].toStringAsFixed(1)}% chance of selling',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  CircularProgressIndicator(
                    value: _pricingSuggestions!['salesProbability'] / 100,
                    backgroundColor: Colors.blue[100],
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            ...['moderate', 'aggressive', 'conservative'].map((type) {
              final option = _pricingSuggestions![type];
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[200]!),
                  borderRadius: BorderRadius.circular(8),
                  color: type == 'moderate' ? Colors.green[50] : null,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            option['description'],
                            style: TextStyle(
                              fontWeight: type == 'moderate' ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          Text(
                            '${option['discountPercentage']}% OFF',
                            style: TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            option['recommendedFor'],
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      children: [
                        Text(
                          'RM${option['price'].toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.deepOrange,
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _discountPriceController.text = option['price'].toStringAsFixed(2);
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            backgroundColor: type == 'moderate' ? Colors.green : Colors.grey[300],
                          ),
                          child: Text(
                            'Use',
                            style: TextStyle(
                              color: type == 'moderate' ? Colors.white : Colors.black,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
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

  Color _getConfidenceColor(double confidence) {
    if (confidence > 0.8) return Colors.green;
    if (confidence > 0.5) return Colors.orange;
    return Colors.red;
  }

  String _getConfidenceText(double confidence) {
    if (confidence > 0.8) return 'High';
    if (confidence > 0.5) return 'Medium';
    return 'Low';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Food Item'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildImageSection(),
              const SizedBox(height: 16),

              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Food Name *',
                  border: OutlineInputBorder(),
                  hintText: 'e.g., Chicken Burger, Sushi Platter',
                ),
                maxLength: 100, // Add character limit
                inputFormatters: [
                  LengthLimitingTextInputFormatter(100),
                ],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Food name is required';
                  }

                  final trimmedValue = value.trim();
                  if (trimmedValue.isEmpty) {
                    return 'Food name cannot be empty';
                  }

                  // Check for invalid characters
                  final invalidChars = RegExp(r'[<>:"/\\|?*]');
                  if (invalidChars.hasMatch(trimmedValue)) {
                    return 'Food name contains invalid characters (< > : " / \\ | ? *)';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Description
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),

              // Prices
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _originalPriceController,
                      decoration: const InputDecoration(
                        labelText: 'Original Price (RM) *',
                        border: OutlineInputBorder(),
                        prefixText: 'RM ',
                      ),
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => _calculatePricingSuggestions(),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter price';
                        }
                        final price = double.tryParse(value);
                        if (price == null || price <= 0) {
                          return 'Please enter a valid price';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _discountPriceController,
                      decoration: const InputDecoration(
                        labelText: 'Discount Price (RM) *',
                        border: OutlineInputBorder(),
                        prefixText: 'RM ',
                      ),
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter discount price';
                        }
                        final discountPrice = double.tryParse(value);
                        final originalPrice = double.tryParse(_originalPriceController.text);

                        if (discountPrice == null || discountPrice <= 0) {
                          return 'Please enter a valid price';
                        }
                        if (originalPrice != null && discountPrice >= originalPrice) {
                          return 'Discount price must be less than original price';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Quantity
              TextFormField(
                controller: _quantityController,
                decoration: const InputDecoration(
                  labelText: 'Quantity Available *',
                  border: OutlineInputBorder(),
                  hintText: '1-999',
                  suffixText: 'units',
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(3),
                ],
                onChanged: (_) => _calculatePricingSuggestions(),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Quantity is required';
                  }

                  final quantity = int.tryParse(value);
                  if (quantity == null) {
                    return 'Please enter a valid number';
                  }

                  if (quantity <= 0) {
                    return 'Quantity must be at least 1';
                  }

                  if (quantity > 999) {
                    return 'Maximum quantity is 999';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Pickup Times
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Pickup Times *',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _selectTime(true),
                              icon: const Icon(Icons.access_time),
                              label: Text('Start: ${_pickupStart.format(context)}'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _selectTime(false),
                              icon: const Icon(Icons.access_time),
                              label: Text('End: ${_pickupEnd.format(context)}'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Expiry Date & Time
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Expiry Date & Time * (For Pricing Suggestions)',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _selectExpiryDateTime,
                        icon: const Icon(Icons.calendar_today),
                        label: Text(
                          _selectedExpiryDate != null
                              ? 'Expires: ${DateFormat('MMM dd, hh:mm a').format(_selectedExpiryDate!)}'
                              : 'Set Expiry for Pricing Suggestions',
                        ),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Setting an expiry time enables AI-powered dynamic pricing suggestions',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              if (_showPricingSuggestions) ...[
                _buildPricingSuggestions(),
                const SizedBox(height: 16),
              ],

              _buildCategorySection(),
              const SizedBox(height: 24),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isLoading ? null : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(color: Colors.grey[300]!),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),

                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submitFoodItem,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.green,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                          : const Text(
                        'Add Food Item',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}