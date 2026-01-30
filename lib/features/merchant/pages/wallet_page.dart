import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fyp_savr/data/services/firebase_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fyp_savr/data/services/wallet_service.dart';

class WalletPage extends StatefulWidget {
  const WalletPage({super.key});

  @override
  State<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> {
  double _balance = 0.0;
  List<QueryDocumentSnapshot> _transactions = [];
  bool _isLoading = true;
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _loadWalletData();
  }

  Future<void> _loadWalletData() async {
    try {
      if (_currentUser != null) {
        final walletDoc = await FirebaseService.wallets.doc(_currentUser!.uid).get();
        if (walletDoc.exists) {
          final data = walletDoc.data() as Map<String, dynamic>?;
          setState(() {
            _balance = (data?['balance'] ?? 0.0).toDouble();
          });
        }

        final transactionsQuery = await FirebaseService.payments
            .where('restaurantId', isEqualTo: _currentUser!.uid)
            .orderBy('createdAt', descending: true)
            .limit(10)
            .get();

        setState(() {
          _transactions = transactionsQuery.docs;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading wallet data: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Merchant Wallet'),
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadWalletData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              color: Colors.deepOrange.withOpacity(0.05),
              child: Column(
                children: [
                  const Text(
                    'AVAILABLE BALANCE',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'RM${_balance.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepOrange,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _balance > 0
                        ? 'Ready to withdraw'
                        : 'No funds available',
                    style: TextStyle(
                      fontSize: 14,
                      color: _balance > 0 ? Colors.green : Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _withdrawFunds,
                      icon: const Icon(Icons.download_rounded, size: 20),
                      label: const Text(
                        'WITHDRAW FUNDS',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _balance > 0 ? Colors.green : Colors.grey,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Recent Transactions',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _transactions.isEmpty
                      ? _buildEmptyTransactions()
                      : Column(
                    children: _transactions
                        .map((doc) => _buildTransactionItem(doc))
                        .toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionItem(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final amount = (data['amount'] ?? 0.0).toDouble();
    final orderId = data['orderId'] ?? '';
    final type = data['type'] ?? 'sale';
    final status = data['status'] ?? 'pending';
    final createdAt = data['createdAt'] != null
        ? (data['createdAt'] as Timestamp).toDate()
        : DateTime.now();
    final description = data['description'] ?? '';

    final isWithdrawal = type == 'withdrawal';
    final amountText = isWithdrawal
        ? 'RM${amount.abs().toStringAsFixed(2)}'
        : 'RM${amount.toStringAsFixed(2)}';
    final icon = isWithdrawal ? Icons.upload : Icons.download;
    final color = isWithdrawal ? Colors.orange :
    status == 'pending' ? Colors.amber : Colors.green;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(
          isWithdrawal
              ? (description.isNotEmpty ? description : 'Withdrawal')
              : 'Order #${orderId.length > 6 ? orderId.substring(0, 6) : orderId}',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_formatDate(createdAt)} • ${_formatTime(createdAt)}',
              style: const TextStyle(fontSize: 11),
            ),
            if (status == 'pending' && !isWithdrawal)
              Container(
                margin: const EdgeInsets.only(top: 2),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.amber),
                ),
                child: const Text(
                  'PENDING - Will release when order completed',
                  style: TextStyle(
                    fontSize: 9,
                    color: Colors.amber,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              isWithdrawal ? '-$amountText' : '+$amountText',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: isWithdrawal ? Colors.orange :
                status == 'pending' ? Colors.amber : Colors.green,
              ),
            ),
            Text(
              isWithdrawal ? 'Withdrawn' : status,
              style: TextStyle(
                fontSize: 10,
                color: isWithdrawal ? Colors.orange :
                status == 'pending' ? Colors.amber : Colors.green,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyTransactions() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 48,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 12),
          const Text(
            'No transactions yet',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Completed transactions will appear here',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Future<void> _withdrawFunds() async {
    setState(() => _isLoading = true);

    try {
      if (_balance <= 0) {
        _showNoBalanceError();
        return;
      }

      const double minimumWithdrawal = 1.00;
      if (_balance < minimumWithdrawal) {
        _showMinimumAmountError(minimumWithdrawal);
        return;
      }

      final bool? confirm = await _showWithdrawalConfirmation();
      if (confirm != true) {
        setState(() => _isLoading = false);
        return;
      }

      await WalletService.withdrawFromWallet(_currentUser!.uid, _balance);

      _showWithdrawalSuccess();

      await _loadWalletData();

    } catch (e) {
      if (e.toString().contains('Insufficient funds') ||
          e.toString().contains('Wallet not found') ||
          e.toString().contains('balance is RM0.00')) {
        _showNoBalanceError();
      } else if (e.toString().contains('network') ||
          e.toString().contains('connection')) {
        _showNetworkError();
      } else {
        _showGenericError(e.toString());
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }


  void _showNoBalanceError() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.account_balance_wallet, color: Colors.orange),
            SizedBox(width: 10),
            Text('No Balance Available'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your wallet balance is RM0.00.',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 10),
            Text(
              'You need to complete orders to receive payments from customers.',
              style: TextStyle(color: Colors.grey),
            ),
            SizedBox(height: 10),
            Text(
              'Completed orders will release payments to your wallet automatically.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
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

  void _showMinimumAmountError(double minimum) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: Colors.orange),
            SizedBox(width: 10),
            Text('Minimum Amount Required'),
          ],
        ),
        content: Text(
          'Minimum withdrawal amount is RM${minimum.toStringAsFixed(2)}.\n'
              'Your current balance is RM${_balance.toStringAsFixed(2)}.',
          style: const TextStyle(fontSize: 16),
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

  Future<bool?> _showWithdrawalConfirmation() async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Withdrawal'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Amount: RM${_balance.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              'The funds will be transferred to your registered bank account within 3-5 business days.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Important Information:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 5),
                  Text('• Processing time: 3-5 business days'),
                  Text('• Transaction fee: RM0.00'),
                  Text('• Minimum withdrawal: RM1.00'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirm Withdrawal'),
          ),
        ],
      ),
    );
  }

  void _showWithdrawalSuccess() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 10),
            Text('Withdrawal Successful'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'RM${_balance.toStringAsFixed(2)} has been withdrawn from your wallet.',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'What happens next:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text('✓ Funds will be processed within 24 hours'),
                  Text('✓ Transfer to your bank in 3-5 business days'),
                  Text('✓ You will receive an email confirmation'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  void _showNetworkError() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.wifi_off, color: Colors.red),
            SizedBox(width: 10),
            Text('Network Error'),
          ],
        ),
        content: const Text(
          'Unable to process withdrawal due to network issues. '
              'Please check your internet connection and try again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _withdrawFunds(); // Retry
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  void _showGenericError(String error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error, color: Colors.red),
            SizedBox(width: 10),
            Text('Withdrawal Failed'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'An unexpected error occurred:',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                error,
                style: const TextStyle(fontSize: 12, color: Colors.red),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Please try again or contact support if the problem persists.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
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

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatTime(DateTime date) {
    return '${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}