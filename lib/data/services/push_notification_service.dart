import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fyp_savr/data/services/firebase_service.dart';
import 'package:fyp_savr/data/services/service_account_service.dart';
import '../../features/customer/pages/customer_order_page.dart';

class PushNotificationService {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  static final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
  FlutterLocalNotificationsPlugin();static void _navigateBasedOnMessage(Map<String, dynamic> data) {
    final type = data['type'] ?? '';
    final orderId = data['orderId'] ?? data['order_id'] ?? '';
    final screen = data['screen'] ?? '';
    final orderNumber = data['orderNumber'] ?? '';

    print('📍 Notification navigation: type=$type, screen=$screen, orderId=$orderId');

    if (navigatorKey.currentContext != null) {
      if (screen == 'order_history' || type.contains('order')) {
        Navigator.of(navigatorKey.currentContext!).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => CustomerOrderHistoryPage(orderId: orderId),
          ),
              (route) => route.isFirst,
        );
      }
    } else {
      print('Navigator key not initialized');
    }
  }

  static final AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'order_notifications',
    'Order Updates',
    description: 'Notifications for order status updates',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
    enableLights: true,
    ledColor: Colors.orange,
  );

  static StreamController<Map<String, dynamic>> _notificationStreamController =
  StreamController.broadcast();

  static Stream<Map<String, dynamic>> get notificationStream =>
      _notificationStreamController.stream;

  static Future<void> initialize() async {
    print('🚀 Initializing push notifications...');

    await _requestPermission();

    await _getAndSaveDeviceToken();

    await _setupLocalNotifications();

    await _setupMessageHandlers();
  }

  static Future<void> _requestPermission() async {
    try {
      NotificationSettings settings = await _firebaseMessaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      print('Notification permission status: ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        print('Notification permission granted');
      } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
        print('Provisional notification permission granted');
      } else {
        print('Notification permission denied');
      }
    } catch (e) {
      print('Error requesting notification permission: $e');
    }
  }

  static Future<void> _getAndSaveDeviceToken() async {
    try {
      String? token = await _firebaseMessaging.getToken();

      if (token != null && token.isNotEmpty) {
        await _saveTokenToFirestore(token);
      } else {
        print('Failed to get device token');
      }

      _firebaseMessaging.onTokenRefresh.listen((newToken) {
        print('Token refreshed: $newToken');
        _saveTokenToFirestore(newToken);
      });
    } catch (e) {
      print('Error getting token: $e');
    }
  }

  static void navigateBasedOnMessage(Map<String, dynamic> data) {
    final type = data['type'] ?? '';
    final orderId = data['orderId'] ?? data['order_id'] ?? '';
    final screen = data['screen'] ?? '';
    final orderNumber = data['orderNumber'] ?? '';

    print('📍 Notification navigation: type=$type, screen=$screen, orderId=$orderId');

    if (navigatorKey.currentContext != null) {
      if (screen == 'order_history' || type.contains('order')) {
        Navigator.of(navigatorKey.currentContext!).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => CustomerOrderHistoryPage(orderId: orderId),
          ),
              (route) => route.isFirst,
        );
      }
    } else {
      print('⚠️ Navigator key not initialized yet');
    }
  }

  static Future<void> _saveTokenToFirestore(String token) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {

        await FirebaseService.users.doc(currentUser.uid).set({
          'fcmTokens': FieldValue.arrayUnion([token]),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        await _saveDeviceUserMapping(currentUser.uid, token);
      } else {
        print('⚠️ No user logged in - token saved to temporary storage');
      }
    } catch (e) {
      print('Error saving token: $e');
    }
  }

  static Future<void> _saveDeviceUserMapping(String userId, String token) async {
    await FirebaseFirestore.instance
        .collection('device_mappings')
        .doc(token)
        .set({
      'userId': userId,
      'lastUpdated': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> _setupLocalNotifications() async {
    try {
      const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

      final InitializationSettings initializationSettings =
      InitializationSettings(android: initializationSettingsAndroid);

      await _localNotificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          print('📱 Notification tapped: ${response.payload}');
          _handleNotificationTap(response.payload as Map<String, dynamic>);
        },
      );

      await _localNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_channel);

      print('Local notifications initialized');
    } catch (e) {
      print('Error initializing local notifications: $e');
    }
  }

  static Future<void> _setupMessageHandlers() async {
    print('🔧 Setting up message handlers...');

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('📱 Message received (foreground)');
      print('📱 Has notification: ${message.notification != null}');
      print('📱 Has data: ${message.data.isNotEmpty}');
      print('📱 Data: ${message.data}');

      _handleForegroundMessage(message);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('📱 App opened via notification (background)');
      _handleNotificationTap(message.data);
    });

    RemoteMessage? initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      print('📱 App launched via notification from terminated state');
      _handleNotificationTap(initialMessage.data);
    }

    await _setupLocalNotificationTapHandler();
  }

  static Future<void> _setupLocalNotificationTapHandler() async {
    try {
      const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

      final InitializationSettings initializationSettings =
      InitializationSettings(android: initializationSettingsAndroid);

      await _localNotificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {

          try {
            if (response.payload != null && response.payload!.isNotEmpty) {
              final payload = response.payload!;

              if (payload.startsWith('{') && payload.endsWith('}')) {
                try {
                  final Map<String, dynamic> data = json.decode(payload);
                  _handleNotificationTap(data);
                } catch (e) {
                  print('JSON parsing failed, trying string parsing');
                  _parseStringPayload(payload);
                }
              } else {
                _parseStringPayload(payload);
              }
            }
          } catch (e) {
            print('Error parsing notification payload: $e');
          }
        },
      );

      print('Local notification tap handler initialized');
    } catch (e) {
      print('Error initializing local notification tap handler: $e');
    }
  }

  static void _parseStringPayload(String payload) {
    try {
      final cleanedPayload = payload
          .replaceAll('{', '')
          .replaceAll('}', '')
          .replaceAll(' ', '');

      final Map<String, dynamic> data = {};
      final pairs = cleanedPayload.split(',');

      for (final pair in pairs) {
        final keyValue = pair.split(':');
        if (keyValue.length == 2) {
          final key = keyValue[0].trim();
          final value = keyValue[1].trim();
          data[key] = value;
        }
      }

      _handleNotificationTap(data);
    } catch (e) {
      print('Error parsing string payload: $e');
    }
  }

  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    try {
      final notification = message.notification;
      final data = message.data;

      String displayTitle;
      String displayBody;

      if (notification != null && notification.title != null && notification.body != null) {
        displayTitle = notification.title!;
        displayBody = notification.body!;
      } else if (data['title'] != null && data['body'] != null) {
        displayTitle = data['title']!;
        displayBody = data['body']!;
      } else {
        displayTitle = _generateTitleFromData(data);
        displayBody = _generateBodyFromData(data);
      }

      print('📱 Will show: "$displayTitle" - "$displayBody"');

      await _showLocalNotification(
        title: displayTitle,
        body: displayBody,
        data: data,
      );

      _notificationStreamController.add({
        'type': 'message',
        'data': data,
        'notification': {
          'title': displayTitle,
          'body': displayBody,
        },
      });

    } catch (e) {
      print('❌ Error handling foreground message: $e');
    }
  }

  static String _generateTitleFromData(Map<String, dynamic> data) {
    final type = data['type'] ?? '';

    switch (type) {
      case 'new_order':
        return '🎉 New Order!';
      case 'order_status_update':
        return '🔄 Order Updated';
      case 'merchant_order_update':
        return '🏪 Order Update';
      default:
        return 'New Notification';
    }
  }

  static String _generateBodyFromData(Map<String, dynamic> data) {
    final type = data['type'] ?? '';
    final orderNumber = data['orderNumber'] ?? '';
    final customerName = data['customerName'] ?? '';
    final newStatus = data['newStatus'] ?? '';

    if (type == 'merchant_order_update') {
      switch (newStatus) {
        case 'picked_up_by_customer':
          return 'Customer $customerName picked up order #${orderNumber.substring(0, 8)}';
        case 'completed':
          return 'Order #${orderNumber.substring(0, 8)} payment released';
        default:
          return 'Order #${orderNumber.substring(0, 8)} status: $newStatus';
      }
    }

    if (type == 'order_status_update') {
      return 'Order #${orderNumber.substring(0, 8)} is now $newStatus';
    }

    return 'You have a new update';
  }

  static Future<void> _showLocalNotification({
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) async {
    try {
      final AndroidNotificationDetails androidPlatformChannelSpecifics =
      AndroidNotificationDetails(
        'order_notifications',
        'Order Updates',
        channelDescription: 'Notifications for order status updates',
        importance: Importance.high,
        priority: Priority.high,
        ticker: title,
        playSound: true,
        enableVibration: true,
        enableLights: true,
        ledColor: Colors.orange,
        ledOnMs: 1000,
        ledOffMs: 500,
        styleInformation: BigTextStyleInformation(body),
        icon: 'ic_notification',
        color: Colors.orange,
        channelShowBadge: true,
        autoCancel: true,
        onlyAlertOnce: true,
      );

      final NotificationDetails platformChannelSpecifics =
      NotificationDetails(android: androidPlatformChannelSpecifics);

      final payload = json.encode(data);

      final notificationId = (data['orderId']?.hashCode ?? DateTime.now().millisecondsSinceEpoch) & 0x7fffffff;

      await _localNotificationsPlugin.show(
        notificationId,
        title,
        body,
        platformChannelSpecifics,
        payload: payload,
      );

      print('Local notification shown (ID: $notificationId)');
    } catch (e) {
      print('Error showing local notification: $e');
    }
  }

  static void _handleNotificationTap(Map<String, dynamic> data) {
    try {
      print('Handling notification tap with data: $data');

      final type = data['type'] ?? '';
      final orderId = data['orderId'] ?? '';
      final screen = data['screen'] ?? '';

      print('Type: $type, Order ID: $orderId, Screen: $screen');

      _notificationStreamController.add({
        'type': 'notification_tap',
        'data': data,
        'action': 'navigate',
      });

      _navigateBasedOnMessage(data);

    } catch (e) {
      print('❌ Error handling notification tap: $e');
    }
  }

  static Future<void> sendPushNotification({
    required String userId,
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) async {
    try {
      print('=' * 50);

      final userDoc = await FirebaseService.users.doc(userId).get();
      final userData = userDoc.data() as Map<String, dynamic>?;

      if (userData == null || !userDoc.exists) {
        print('User not found - cannot send notifications');
        return;
      }

      final tokens = (userData['fcmTokens'] as List<dynamic>?)?.cast<String>() ?? [];

      if (tokens.isEmpty) {
        print('No FCM tokens for user $userId');
        return;
      }

      print('Found ${tokens.length} token(s) for user $userId');

      bool success = false;
      String lastError = '';

      for (final token in tokens) {
        print('📱 Trying token: ${token.substring(0, min(30, token.length))}...');

        final tokenSuccess = await ServiceAccountService.sendNotification(
          token: token,
          title: title,
          body: body,
          data: data,
        );

        if (tokenSuccess) {
          print('✅ PUSH NOTIFICATION SENT with token!');
          success = true;
          break;
        } else {
          if (_isTokenInvalid(token)) {
            print('🔄 Removing invalid token from Firestore...');
            await _removeInvalidToken(userId, token);
          }
          lastError = 'Token failed';
        }
      }

      if (!success) {
        print('All tokens failed for user $userId');
        print('⚠User needs to reopen the app to get new FCM token');

        await _showLocalNotificationForMerchant(
          title: title,
          body: body,
          data: data,
          userId: userId,
        );
      }

      print('=' * 50);

    } catch (e) {
      print('Error in sendPushNotification: $e');
      await _showLocalNotificationForMerchant(
        title: title,
        body: body,
        data: data,
        userId: userId,
      );
    }
  }

  static bool _isTokenInvalid(String token) {
    return false;
  }

  static Future<void> _removeInvalidToken(String userId, String invalidToken) async {
    try {
      await FirebaseService.users.doc(userId).update({
        'fcmTokens': FieldValue.arrayRemove([invalidToken]),
      });
      print('✅ Removed invalid token from user $userId');
    } catch (e) {
      print('❌ Error removing invalid token: $e');
    }
  }

  static Future<void> _showLocalNotificationForMerchant({
    required String title,
    required String body,
    required Map<String, dynamic> data,
    required String userId,
  }) async {
    try {
      print('Showing local notification for merchant (FCM failed)');

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null && currentUser.uid == userId) {
        await _showLocalNotification(
          title: title,
          body: body,
          data: data,
        );
        print('Local notification shown for merchant');
      }
    } catch (e) {
      print('Error showing local notification: $e');
    }
  }

  static Future<void> sendBulkNotification({
    required List<String> userIds,
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) async {
    for (final userId in userIds) {
      await sendPushNotification(
        userId: userId,
        title: title,
        body: body,
        data: data,
      );
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  static Future<void> clearAllNotifications() async {
    await _localNotificationsPlugin.cancelAll();
  }

  static Future<NotificationSettings> getNotificationSettings() async {
    return await _firebaseMessaging.getNotificationSettings();
  }

  static Future<void> subscribeToTopic(String topic) async {
    await _firebaseMessaging.subscribeToTopic(topic);
  }

  static Future<void> unsubscribeFromTopic(String topic) async {
    await _firebaseMessaging.unsubscribeFromTopic(topic);
  }

  static Future<void> deleteToken() async {
    await _firebaseMessaging.deleteToken();
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      await FirebaseService.users.doc(currentUser.uid).update({
        'fcmTokens': FieldValue.delete(),
      });
    }
    print('Device token deleted');
  }
}