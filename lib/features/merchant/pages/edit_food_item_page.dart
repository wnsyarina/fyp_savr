import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:fyp_savr/data/services/food_service.dart';
import 'package:fyp_savr/data/services/ml_service.dart';
import 'package:fyp_savr/data/services/imgbb_service.dart';

class EditFoodItemPage extends StatefulWidget {
  final Map<String, dynamic> foodItem;
  final String foodId;

  const EditFoodItemPage({
    super.key,
    required this.foodItem,
    required this.foodId,
  });

  @override
  State<EditFoodItemPage> createState() => _EditFoodItemPageState();
}

class _EditFoodItemPageState extends State<EditFoodItemPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _originalPriceController = TextEditingController();
  final _discountPriceController = TextEditingController();
  final _quantityController = TextEditingController();

  TimeOfDay? _pickupStart;
  TimeOfDay? _pickupEnd;
  
  File? _imageFile;
  String? _currentImageBase64;
  bool _isLoading = false;
  bool _useAICategories = true;
  
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
    _initializeForm();
  }

  void _initializeForm() {
    final food = widget.foodItem;

    _nameController.text = food['name'] ?? '';
    _descriptionController.text = food['description'] ?? '';
    _originalPriceController.text = (food['originalPrice'] ?? 0).toString();
    _discountPriceController.text = (food['discountPrice'] ?? 0).toString();
    _quantityController.text = (food['quantityAvailable'] ?? 0).toString();

    if (food['pickupStart'] != null) {
      final start = (food['pickupStart'] as Timestamp).toDate();
      _pickupStart = TimeOfDay(hour: start.hour, minute: start.minute);
    }

    if (food['pickupEnd'] != null) {
      final end = (food['pickupEnd'] as Timestamp).toDate();
      _pickupEnd = TimeOfDay(hour: end.hour, minute: end.minute);
    }

    _selectedCategories = List<String>.from(food['categories'] ?? []);
    _useAICategories = food['aiSuggestedCategories'] ?? true;
    _currentImageBase64 = food['imageBase64'];

    if (_useAICategories && _selectedCategories.isEmpty) {
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
        
        // Auto-select top category if none selected
        if (_selectedCategories.isEmpty && _suggestedCategories.isNotEmpty) {
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
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 80,
    );

    if (image != null) {
      setState(() {
        _imageFile = File(image.path);
        _currentImageBase64 = null;
      });
    }
  }

  Future<void> _updateFoodItem() async {
    if (_formKey.currentState!.validate()) {
      if (_pickupStart == null || _pickupEnd == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please set pickup times')),
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
        String? imageUrl;

        if (_imageFile != null) {
          imageUrl = await ImgBBService.uploadImage(_imageFile!);

          if (imageUrl == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to upload image. Please try again.')),
            );
            setState(() => _isLoading = false);
            return;
          }
        }

        final now = DateTime.now();
        final pickupStart = DateTime(
          now.year, now.month, now.day,
          _pickupStart!.hour, _pickupStart!.minute,
        );
        final pickupEnd = DateTime(
          now.year, now.month, now.day,
          _pickupEnd!.hour, _pickupEnd!.minute,
        );

        if (pickupEnd.isBefore(pickupStart)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Pickup end time must be after start time')),
          );
          setState(() => _isLoading = false);
          return;
        }

        Map<String, dynamic> updateData = {
          'name': _nameController.text.trim(),
          'description': _descriptionController.text.trim(),
          'originalPrice': double.parse(_originalPriceController.text),
          'discountPrice': double.parse(_discountPriceController.text),
          'quantityAvailable': int.parse(_quantityController.text),
          'pickupStart': pickupStart,
          'pickupEnd': pickupEnd,
          'categories': _selectedCategories,
          'aiSuggestedCategories': _useAICategories && _selectedCategories.isEmpty,
          'aiConfidenceScores': await MLService.getPredictionConfidence(
            foodName: _nameController.text,
            description: _descriptionController.text,
          ),
          'manualOverride': _selectedCategories.isNotEmpty && _useAICategories,
          'updatedAt': DateTime.now(),
        };

        if (imageUrl != null) {
          updateData['imageUrl'] = imageUrl;
          updateData['imageBase64'] = null;
        }

        await FoodService.updateFoodItem(widget.foodId, updateData);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Food item updated successfully!')),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error updating food item: ${e.toString()}')),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteFoodItem() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Food Item?'),
        content: const Text('This action cannot be undone. The food item will be removed from your listings.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _isLoading = true);
              
              try {
                await FoodService.deleteFoodItem(widget.foodId);
                
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Food item deleted successfully')),
                  );
                  Navigator.pop(context);
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error deleting food item: ${e.toString()}')),
                  );
                }
              } finally {
                if (mounted) setState(() => _isLoading = false);
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
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
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 150,
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _imageFile != null
                    ? Image.file(_imageFile!, fit: BoxFit.cover)
                    : widget.foodItem['imageUrl'] != null && widget.foodItem['imageUrl'].isNotEmpty
                    ? CachedNetworkImage(
                  imageUrl: widget.foodItem['imageUrl'],
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Center(
                    child: CircularProgressIndicator(),
                  ),
                  errorWidget: (context, url, error) => _buildImagePlaceholder(),
                )
                    : _currentImageBase64 != null && _currentImageBase64!.isNotEmpty
                    ? Image.memory(
                  base64Decode(_currentImageBase64!),
                  fit: BoxFit.cover,
                )
                    : _buildImagePlaceholder(),
              ),
            ),
            if (_imageFile != null || _currentImageBase64 != null) ...[
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () {
                  setState(() {
                    _imageFile = null;
                    _currentImageBase64 = null;
                  });
                },
                child: const Text('Remove Image'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.camera_alt, size: 40, color: Colors.grey),
        SizedBox(height: 8),
        Text('Tap to upload food image'),
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

  Future<void> _selectTime(bool isStart) async {
    final initialTime = isStart ? _pickupStart : _pickupEnd;
    final selectedTime = await showTimePicker(
      context: context,
      initialTime: initialTime ?? TimeOfDay.now(),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Food Item'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: _isLoading ? null : _deleteFoodItem,
            tooltip: 'Delete Food Item',
          ),
        ],
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

                    // Food Name
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Food Name *',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => _predictCategories(),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter food name';
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
                      onChanged: (_) => _predictCategories(),
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
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter price';
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
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter quantity';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

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
                                    label: Text(
                                      _pickupStart != null
                                          ? 'Start: ${_pickupStart!.format(context)}'
                                          : 'Set Start Time',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => _selectTime(false),
                                    icon: const Icon(Icons.access_time),
                                    label: Text(
                                      _pickupEnd != null
                                          ? 'End: ${_pickupEnd!.format(context)}'
                                          : 'Set End Time',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    _buildCategorySection(),
                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _updateFoodItem,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text('Update Food Item'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
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
}