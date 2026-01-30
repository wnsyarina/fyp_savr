import 'dart:async';
import 'package:fyp_savr/features/auth/pages/landing_page.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fyp_savr/utils/navigation_utils.dart';

class EmailVerificationPage extends StatefulWidget {
  final User user;
  const EmailVerificationPage({super.key, required this.user});

  @override
  State<EmailVerificationPage> createState() => _EmailVerificationPageState();
}

class _EmailVerificationPageState extends State<EmailVerificationPage> {
  bool _isLoading = false;
  bool _isEmailSent = false;
  bool _isChecking = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startVerificationCheck();
  }

  void _startVerificationCheck() {
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _checkEmailVerified();
    });
  }

  Future<void> _checkEmailVerified() async {
    if (_isChecking) return;

    setState(() => _isChecking = true);
    try {
      await widget.user.reload();
      final updatedUser = FirebaseAuth.instance.currentUser;

      if (updatedUser != null && updatedUser.emailVerified) {
        _timer?.cancel();
        if (mounted) {
          await NavigationUtils.navigateAfterVerification(context, updatedUser.uid);
        }
      }
    } catch (e) {
    } finally {
      if (mounted && !widget.user.emailVerified) {
        setState(() => _isChecking = false);
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _sendVerificationEmail() async {
    setState(() => _isLoading = true);
    try {
      await widget.user.sendEmailVerification();
      setState(() => _isEmailSent = true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Verification email sent!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send email: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _logout() async {
    try {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LandingPage()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Logout failed: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify Your Email'),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _logout,
            child: const Text('Cancel', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              Icons.mark_email_unread_outlined,
              size: 80,
              color: Theme.of(context).primaryColor,
            ),
            const SizedBox(height: 24),
            const Text(
              'Verify Your Email Address',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: const TextStyle(fontSize: 16, color: Colors.black),
                children: [
                  const TextSpan(text: 'We sent a verification link to '),
                  TextSpan(
                    text: widget.user.email,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const TextSpan(text: '. Please check your inbox and click the link to activate your account.'),
                ],
              ),
            ),
            const SizedBox(height: 32),
            if (_isEmailSent)
              const Text(
                '✔ Email sent successfully',
                style: TextStyle(color: Colors.green),
                textAlign: TextAlign.center,
              ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _sendVerificationEmail,
              icon: _isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.email_outlined),
              label: Text(_isEmailSent ? 'Resend Email' : 'Send Verification Email'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _isChecking ? null : _checkEmailVerified,
              icon: _isChecking
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
              label: const Text('I\'ve Verified My Email'),
            ),
            const SizedBox(height: 32),
            const Text(
              'Didn\'t receive the email?',
              style: TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Troubleshooting'),
                    content: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('1. Check your spam/junk folder'),
                        SizedBox(height: 8),
                        Text('2. Wait a few minutes for the email to arrive'),
                        SizedBox(height: 8),
                        Text('3. Ensure you entered the correct email address'),
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
              },
              child: const Text('Need help?'),
            ),
          ],
        ),
      ),
    );
  }
}