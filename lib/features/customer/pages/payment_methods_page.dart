import 'package:flutter/material.dart';
import 'package:fyp_savr/data/services/payment_method_service.dart';

class PaymentMethodsPage extends StatefulWidget {
  const PaymentMethodsPage({super.key});

  @override
  State<PaymentMethodsPage> createState() => _PaymentMethodsPageState();
}

class _PaymentMethodsPageState extends State<PaymentMethodsPage> {
  List<Map<String, dynamic>> _paymentMethods = [];
  bool _isLoading = true;
  bool _showAddCardForm = false;

  final TextEditingController _cardNumberController = TextEditingController();
  final TextEditingController _cardHolderController = TextEditingController();
  final TextEditingController _expiryMonthController = TextEditingController();
  final TextEditingController _expiryYearController = TextEditingController();
  final TextEditingController _cvvController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadPaymentMethods();
  }

  Future<void> _loadPaymentMethods() async {
    setState(() => _isLoading = true);
    try {
      final methods = await PaymentMethodService.getPaymentMethods();
      setState(() {
        _paymentMethods = methods;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading payment methods: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addCard() async {
    if (_cardNumberController.text.isEmpty ||
        _cardHolderController.text.isEmpty ||
        _expiryMonthController.text.isEmpty ||
        _expiryYearController.text.isEmpty ||
        _cvvController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields')),
      );
      return;
    }

    try {
      await PaymentMethodService.addCard(
        cardNumber: _cardNumberController.text,
        cardHolder: _cardHolderController.text,
        expiryMonth: int.parse(_expiryMonthController.text),
        expiryYear: int.parse(_expiryYearController.text),
        cvv: _cvvController.text,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Card added successfully')),
      );

      _clearForm();
      await _loadPaymentMethods();
      setState(() => _showAddCardForm = false);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding card: ${e.toString()}')),
      );
    }
  }

  Future<void> _deleteCard(String cardId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Card'),
        content: const Text('Are you sure you want to delete this card?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await PaymentMethodService.deleteCard(cardId);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Card deleted')),
        );
        await _loadPaymentMethods();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting card: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _setDefaultCard(String cardId) async {
    try {
      await PaymentMethodService.setDefaultCard(cardId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Default card updated')),
      );
      await _loadPaymentMethods();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating default card: ${e.toString()}')),
      );
    }
  }

  void _clearForm() {
    _cardNumberController.clear();
    _cardHolderController.clear();
    _expiryMonthController.clear();
    _expiryYearController.clear();
    _cvvController.clear();
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

  Widget _buildCardItem(Map<String, dynamic> card) {
    final isDefault = card['isDefault'] ?? false;
    final cardNumber = card['cardNumber'] ?? '';
    final last4 = cardNumber.length > 4 ? cardNumber.substring(cardNumber.length - 4) : '';
    final expiryMonth = card['expiryMonth'] ?? '';
    final expiryYear = card['expiryYear'] ?? '';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: ListTile(
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.credit_card, color: Colors.blue),
        ),
        title: Row(
          children: [
            Text('•••• $last4'),
            if (isDefault)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(12),
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
          ],
        ),
        subtitle: Text('Expires ${expiryMonth.toString().padLeft(2, '0')}/$expiryYear'),
        trailing: PopupMenuButton(
          itemBuilder: (context) => [
            if (!isDefault)
              const PopupMenuItem(
                value: 'set_default',
                child: Row(
                  children: [
                    Icon(Icons.star, size: 20),
                    SizedBox(width: 8),
                    Text('Set as Default'),
                  ],
                ),
              ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, color: Colors.red, size: 20),
                  SizedBox(width: 8),
                  Text('Delete'),
                ],
              ),
            ),
          ],
          onSelected: (value) {
            if (value == 'set_default') {
              _setDefaultCard(card['id']);
            } else if (value == 'delete') {
              _deleteCard(card['id']);
            }
          },
        ),
      ),
    );
  }

  Widget _buildAddCardForm() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Add New Card',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _cardHolderController,
              decoration: const InputDecoration(
                labelText: 'Card Holder Name',
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
                    obscureText: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () {
                      _clearForm();
                      setState(() => _showAddCardForm = false);
                    },
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _addCard,
                    child: const Text('Add Card'),
                  ),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Methods'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          if (_showAddCardForm) _buildAddCardForm(),
          Expanded(
            child: _paymentMethods.isEmpty && !_showAddCardForm
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.credit_card_off,
                    size: 80,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No Payment Methods',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Add a card to make purchases',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => setState(() => _showAddCardForm = true),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Card'),
                  ),
                ],
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 16),
              itemCount: _paymentMethods.length,
              itemBuilder: (context, index) => _buildCardItem(_paymentMethods[index]),
            ),
          ),
          if (!_showAddCardForm)
            Container(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton.icon(
                onPressed: () => setState(() => _showAddCardForm = true),
                icon: const Icon(Icons.add),
                label: const Text('Add New Card'),
              ),
            ),
        ],
      ),
    );
  }
}