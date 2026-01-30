import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fyp_savr/data/services/cart_service.dart';
import 'package:fyp_savr/data/models/cart_item_model.dart';
import 'package:fyp_savr/data/services/payment_method_service.dart';

class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Cart'),
      ),
      body: StreamBuilder<List<CartItem>>(
        stream: CartService.getCartItemsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, color: Colors.red, size: 64),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => setState(() {}),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final cartItems = snapshot.data ?? [];

          if (cartItems.isEmpty) {
            return _buildEmptyCart();
          }

          return _buildCartContent(cartItems);
        },
      ),
    );
  }

  Widget _buildCartContent(List<CartItem> cartItems) {
    final totalPrice = cartItems.fold(
        0.0,
            (sum, item) => sum + (item.price * item.quantity)
    );

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 100),
            itemCount: cartItems.length,
            itemBuilder: (context, index) {
              final item = cartItems[index];
              return _buildCartItem(item);
            },
          ),
        ),

        _buildCheckoutSection(cartItems, totalPrice),
      ],
    );
  }

  Widget _buildCartItem(CartItem item) {
    return Dismissible(
      key: Key('${item.foodId}-${item.quantity}'),
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white, size: 30),
      ),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Remove Item'),
            content: const Text('Remove this item from your cart?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Remove', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
      },
      onDismissed: (direction) => _removeItem(item.foodId),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Food Image
              item.imageBase64 != null && item.imageBase64!.isNotEmpty
                  ? Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  image: DecorationImage(
                    image: MemoryImage(base64.decode(item.imageBase64!)),
                    fit: BoxFit.cover,
                  ),
                ),
              )
                  : Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.fastfood, color: Colors.grey, size: 40),
              ),

              const SizedBox(width: 16),

              // Item Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.foodName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.restaurantName,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'RM${item.price.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ),

              // Quantity Controls
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove, size: 18),
                      onPressed: () {
                        _updateQuantity(item.foodId, item.quantity - 1);
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    ),
                    Container(
                      width: 30,
                      alignment: Alignment.center,
                      child: Text(
                        item.quantity.toString(),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add, size: 18),
                      onPressed: () {
                        _updateQuantity(item.foodId, item.quantity + 1);
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCheckoutSection(List<CartItem> cartItems, double totalPrice) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey.shade200),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        children: [
          // Order Summary
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${cartItems.length} item${cartItems.length != 1 ? 's' : ''}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'RM${totalPrice.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
                TextButton.icon(
                  onPressed: () => _clearCart(cartItems),
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: const Text('Clear All'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
              onPressed: () => _navigateToPayment(context, cartItems, totalPrice),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shopping_cart_checkout, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'PROCEED TO CHECKOUT',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 8),

        ],
      ),
    );
  }

  Widget _buildEmptyCart() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_cart_outlined,
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 24),
          const Text(
            'Your cart is empty',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 12),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Browse restaurants and add delicious food items to your cart',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
            },
            icon: const Icon(Icons.restaurant),
            label: const Text('Browse Restaurants'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToPayment(BuildContext context, List<CartItem> cartItems, double totalPrice) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PaymentSelectionPage(
          cartItems: cartItems,
          totalAmount: totalPrice,
        ),
      ),
    );
  }

  Future<void> _updateQuantity(String foodId, int newQuantity) async {
    if (newQuantity <= 0) {
      await _removeItem(foodId);
    } else {
      try {
        await CartService.updateCartItemQuantity(foodId, newQuantity);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _removeItem(String foodId) async {
    try {
      await CartService.removeFromCart(foodId);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Item removed from cart'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _clearCart(List<CartItem> cartItems) async {
    if (cartItems.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Cart'),
        content: const Text('Remove all items from your cart?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear All', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await CartService.clearCart();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cart cleared'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class PaymentSelectionPage extends StatefulWidget {
  final List<CartItem> cartItems;
  final double totalAmount;

  const PaymentSelectionPage({
    super.key,
    required this.cartItems,
    required this.totalAmount,
  });

  @override
  State<PaymentSelectionPage> createState() => _PaymentSelectionPageState();
}

class _PaymentSelectionPageState extends State<PaymentSelectionPage> {
  String _selectedPaymentMethod = 'saved_card';
  String? _selectedCardId;
  List<Map<String, dynamic>> _savedCards = [];
  bool _isLoading = true;
  bool _isProcessing = false;
  bool _showNewCardForm = false;

  final TextEditingController _cardNumberController = TextEditingController();
  final TextEditingController _cardHolderController = TextEditingController();
  final TextEditingController _expiryMonthController = TextEditingController();
  final TextEditingController _expiryYearController = TextEditingController();
  final TextEditingController _cvvController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSavedCards();
  }

  Future<void> _loadSavedCards() async {
    setState(() => _isLoading = true);
    try {
      final cards = await PaymentMethodService.getPaymentMethods();
      setState(() {
        _savedCards = cards;
        _isLoading = false;

        if (_savedCards.isNotEmpty) {
          _selectedCardId = _savedCards.first['id'];
          _selectedPaymentMethod = 'saved_card';
        } else {
          // No saved cards, show new card form
          _selectedPaymentMethod = 'new_card';
          _showNewCardForm = true;
        }
      });
    } catch (e) {
      print('Error loading saved cards: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _processPayment() async {
    setState(() => _isProcessing = true);

    try {
      final validationErrors = await CartService.validateCart();
      if (validationErrors.isNotEmpty) {
        _showValidationErrors(validationErrors);
        setState(() => _isProcessing = false);
        return;
      }

      if (_selectedPaymentMethod == 'saved_card' && _selectedCardId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a payment method')),
        );
        setState(() => _isProcessing = false);
        return;
      }

      if (_selectedPaymentMethod == 'new_card') {
        final errors = PaymentMethodService.validateCard(
          cardNumber: _cardNumberController.text,
          cardHolder: _cardHolderController.text,
          expiryMonth: _expiryMonthController.text,
          expiryYear: _expiryYearController.text,
          cvv: _cvvController.text,
        );

        if (errors.isNotEmpty) {
          _showValidationErrors(errors);
          setState(() => _isProcessing = false);
          return;
        }
      }

      final orderId = await CartService.createOrderFromCart(
        paymentMethod: 'card',
        totalAmount: widget.totalAmount,
      );

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => OrderConfirmationPage(
              orderId: orderId,
              totalAmount: widget.totalAmount,
              paymentMethod: 'Card Payment',
            ),
          ),
        );
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showValidationErrors(List<String> errors) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Validation Error'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Please fix the following issues:'),
              const SizedBox(height: 12),
              ...errors.map((error) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('• $error'),
              )).toList(),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _buildCardItem(Map<String, dynamic> card) {
    final isSelected = _selectedCardId == card['id'];
    final cardNumber = card['maskedNumber'] ?? '•••• •••• •••• 1234';
    final expiryMonth = card['expiryMonth']?.toString().padLeft(2, '0') ?? '01';
    final expiryYear = card['expiryYear']?.toString() ?? '25';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isSelected ? Colors.blue[50] : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? Colors.blue : Colors.transparent,
          width: isSelected ? 2 : 0,
        ),
      ),
      child: ListTile(
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Colors.blue[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.credit_card, color: Colors.blue),
        ),
        title: Text(cardNumber),
        subtitle: Text('Expires ${expiryMonth}/$expiryYear'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (card['isDefault'] == true)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green[100]!),
                ),
                child: Text(
                  'DEFAULT',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.green[700],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            Radio<String>(
              value: card['id'],
              groupValue: _selectedCardId,
              onChanged: (value) {
                setState(() {
                  _selectedCardId = value;
                  _selectedPaymentMethod = 'saved_card';
                });
              },
            ),
          ],
        ),
        onTap: () {
          setState(() {
            _selectedCardId = card['id'];
            _selectedPaymentMethod = 'saved_card';
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Order Summary
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Order Total:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'RM${widget.totalAmount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              const Text(
                'Payment Method',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Select your preferred payment method',
                style: TextStyle(color: Colors.grey),
              ),

              const SizedBox(height: 16),

              if (_savedCards.isNotEmpty) ...[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Saved Cards',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ..._savedCards.map(_buildCardItem),
                    const SizedBox(height: 16),
                    RadioListTile(
                      title: const Text('Use Saved Card'),
                      value: 'saved_card',
                      groupValue: _selectedPaymentMethod,
                      onChanged: (value) {
                        setState(() {
                          _selectedPaymentMethod = value.toString();
                          if (_savedCards.isNotEmpty && _selectedCardId == null) {
                            _selectedCardId = _savedCards.first['id'];
                          }
                        });
                      },
                    ),
                  ],
                ),
              ],

              RadioListTile(
                title: const Text('New Card'),
                value: 'new_card',
                groupValue: _selectedPaymentMethod,
                onChanged: (value) {
                  setState(() {
                    _selectedPaymentMethod = value.toString();
                    _showNewCardForm = true;
                  });
                },
              ),

              if (_selectedPaymentMethod == 'new_card' && _showNewCardForm)
                _buildNewCardForm(),

              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _isProcessing ? null : _processPayment,
                  child: _isProcessing
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                      : const Text(
                    'COMPLETE PAYMENT',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              Row(
                children: [
                  Icon(Icons.lock, color: Colors.green[700], size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Your payment is secured with encryption',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNewCardForm() {
    return Card(
      margin: const EdgeInsets.only(top: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Card Details',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _cardNumberController,
              decoration: const InputDecoration(
                labelText: 'Card Number',
                border: OutlineInputBorder(),
                hintText: '1234 5678 9012 3456',
                prefixIcon: Icon(Icons.credit_card),
              ),
              keyboardType: TextInputType.number,
              maxLength: 19,
            ),

            const SizedBox(height: 12),

            TextField(
              controller: _cardHolderController,
              decoration: const InputDecoration(
                labelText: 'Cardholder Name',
                border: OutlineInputBorder(),
                hintText: 'John Doe',
                prefixIcon: Icon(Icons.person),
              ),
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _expiryMonthController,
                    decoration: const InputDecoration(
                      labelText: 'MM',
                      border: OutlineInputBorder(),
                      hintText: '12',
                      prefixIcon: Icon(Icons.calendar_today),
                    ),
                    keyboardType: TextInputType.number,
                    maxLength: 2,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _expiryYearController,
                    decoration: const InputDecoration(
                      labelText: 'YY',
                      border: OutlineInputBorder(),
                      hintText: '25',
                      prefixIcon: Icon(Icons.calendar_today),
                    ),
                    keyboardType: TextInputType.number,
                    maxLength: 2,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _cvvController,
                    decoration: const InputDecoration(
                      labelText: 'CVV',
                      border: OutlineInputBorder(),
                      hintText: '123',
                      prefixIcon: Icon(Icons.lock),
                    ),
                    keyboardType: TextInputType.number,
                    maxLength: 3,
                    obscureText: true,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            CheckboxListTile(
              title: const Text('Save this card for future payments'),
              value: true,
              onChanged: (value) {},
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _cardNumberController.dispose();
    _cardHolderController.dispose();
    _expiryMonthController.dispose();
    _expiryYearController.dispose();
    _cvvController.dispose();
    super.dispose();
  }
}

class OrderConfirmationPage extends StatelessWidget {
  final String orderId;
  final double totalAmount;
  final String paymentMethod;

  const OrderConfirmationPage({
    super.key,
    required this.orderId,
    required this.totalAmount,
    required this.paymentMethod,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Confirmed'),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 60,
                ),
              ),

              const SizedBox(height: 32),

              const Text(
                'Order Confirmed!',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 16),

              Text(
                'Order #${orderId.substring(0, 8).toUpperCase()}',
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),

              const SizedBox(height: 32),

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total Amount:',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'RM${totalAmount.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Payment Method:',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            paymentMethod,
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Order Time:',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            DateTime.now().toString().substring(0, 16),
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        Navigator.popUntil(context, (route) => route.isFirst);
                      },
                      child: const Text(
                        'BACK TO HOME',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  TextButton(
                    onPressed: () {
                      // TODO: View order details
                    },
                    child: const Text('View Order Details'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}