import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'email_verification_page.dart';
import 'package:fyp_savr/data/services/firebase_service.dart';
import 'package:fyp_savr/utils/constants.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _passwordVisible = false;
  bool _confirmPasswordVisible = false;
  String? _validationError;

  bool _validatePassword(String password) {
    if (password.length < 6) return false;
    if (!password.contains(RegExp(r'[A-Z]'))) return false;
    if (!password.contains(RegExp(r'[a-z]'))) return false;
    if (!password.contains(RegExp(r'[0-9]'))) return false;
    return true;
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (password != confirmPassword) {
      setState(() => _validationError = 'Passwords do not match');
      return;
    }

    if (!_validatePassword(password)) {
      setState(() => _validationError = 'Password must contain uppercase, lowercase, and numbers');
      return;
    }

    setState(() {
      _isLoading = true;
      _validationError = null;
    });

    try {
      final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: password,
      );
      final user = userCredential.user!;

      await user.updateDisplayName(_nameController.text.trim());

      await FirebaseService.users.doc(user.uid).set({
        'uid': user.uid,
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'role': AppConstants.roleCustomer, // USE CONSTANT
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isEmailVerified': true,
        'phone': '',
        'address': '',
        'profileImageUrl': '',
      });

      await user.sendEmailVerification();

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => EmailVerificationPage(user: user),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'email-already-in-use':
          errorMessage = 'This email is already registered.';
          break;
        case 'invalid-email':
          errorMessage = 'Invalid email format.';
          break;
        case 'weak-password':
          errorMessage = 'Password is too weak. Use at least 6 characters with uppercase, lowercase and numbers.';
          break;
        default:
          errorMessage = 'Registration failed. Please try again.';
      }
      setState(() => _validationError = errorMessage);
    } catch (e) {
      setState(() => _validationError = 'An unexpected error occurred. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Account'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              const SizedBox(height: 20),
              const Icon(Icons.person_add, size: 64, color: Colors.orange),
              const SizedBox(height: 16),
              const Text(
                'Join Savr',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Create an account to start saving',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 32),

              if (_validationError != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _validationError!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ),

              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  prefixIcon: Icon(Icons.person_outline),
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value!.isEmpty ? 'Please enter your name' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value!.isEmpty) return 'Please enter your email';
                  if (!value.contains('@')) return 'Please enter a valid email';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                obscureText: !_passwordVisible,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(_passwordVisible ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _passwordVisible = !_passwordVisible),
                  ),
                ),
                validator: (value) => value!.length < 6 ? 'Minimum 6 characters' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: !_confirmPasswordVisible,
                decoration: InputDecoration(
                  labelText: 'Confirm Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(_confirmPasswordVisible ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _confirmPasswordVisible = !_confirmPasswordVisible),
                  ),
                ),
                validator: (value) => value!.isEmpty ? 'Please confirm your password' : null,
              ),

              Container(
                margin: const EdgeInsets.symmetric(vertical: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Password must contain:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '• At least 6 characters\n• One uppercase letter\n• One lowercase letter\n• One number',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _register,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.green,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                      : const Text(
                    'Create Account',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),

              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Already have an account?'),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Log In'),
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