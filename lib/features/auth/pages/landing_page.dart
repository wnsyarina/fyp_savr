import 'package:flutter/material.dart';
import 'login_page.dart';
import 'registration_page.dart';
import 'merchant_registration_page.dart';

class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/img/savrlogo.png',
                      height: 300,
                      width: 300,
                      fit: BoxFit.contain,
                    ),
                    const Text(
                      'Save money, reduce waste',
                      style: TextStyle(fontSize: 20),
                    ),
                    const Text(
                      'Get surplus food items nearby you at a discounted price!',
                      style: TextStyle(fontSize: 15),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginPage()),
                      ),
                      child: const Text('Login'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const RegisterPage()),
                      ),
                      child: const Text('Create Account'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Register as:',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MerchantRegistrationPage()),
                ),
                child: const Text('Register as Merchant'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}