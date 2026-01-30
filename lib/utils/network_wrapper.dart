import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fyp_savr/data/services/network_service.dart';
import 'no_internet_screen.dart';

class NetworkWrapper extends StatefulWidget {
  final Widget child;

  const NetworkWrapper({super.key, required this.child});

  @override
  State<NetworkWrapper> createState() => _NetworkWrapperState();
}

class _NetworkWrapperState extends State<NetworkWrapper> {
  bool _isChecking = false;
  bool _hasInternet = true;
  DateTime? _lastCheck;

  @override
  void initState() {
    super.initState();
    _checkConnection();
  }

  Future<void> _checkConnection() async {
    if (_lastCheck != null &&
        DateTime.now().difference(_lastCheck!).inSeconds < 5) {
      return;
    }

    setState(() {
      _isChecking = true;
      _lastCheck = DateTime.now();
    });

    final hasConnection = await NetworkService.hasInternetConnection();

    if (mounted) {
      setState(() {
        _hasInternet = hasConnection;
        _isChecking = false;
      });
    }
  }

  Future<void> _checkConnectionSilently() async {
    final hasConnection = await NetworkService.hasInternetConnection();

    if (mounted && _hasInternet != hasConnection) {
      setState(() {
        _hasInternet = hasConnection;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkConnectionSilently();
    });

    if (_isChecking) {
      return MaterialApp(
        home: Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (!_hasInternet) {
      return MaterialApp(
        home: NoInternetScreen(
          onRetry: _checkConnection,
        ),
      );
    }

    return widget.child;
  }
}
