import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:agora/contabts/constants.dart';
import 'package:agora/model/call_model.dart';
import 'package:agora/services/auth_services.dart';
import 'package:agora/services/fire_store.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import '../screens/call_screen.dart';
import 'package:http/http.dart' as http; // Added http import

class NotificationService {
  static int generate16BitId() {
    return DateTime.now().millisecondsSinceEpoch % 65536; // 2^16 = 65536
  }

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  late FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin;
  final FirestoreService _firestoreService =
      FirestoreService(); // Add FirestoreService

  NotificationService() {
    _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  }

  Future<void> initialize() async {
    _createNotificationChannel();

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings(
            'logo'); // Ensure 'logo' exists in android/app/src/main/res/drawable

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
    );

    final InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        if (kDebugMode) {
          print("Notification tapped with payload: ${response.payload}");
        }
        // Handle notification tap to navigate to CallScreen
        if (response.payload != null) {
          final data = response.payload!.split('|');
          if (data.length >= 2 && data[0] == 'call') {
            final callId = data[1];
            final callDoc = await _firestoreService.getCallStream(callId).first;
            if (callDoc.exists) {
              final call =
                  CallModel.fromMap(callDoc.data() as Map<String, dynamic>);
              Get.toNamed('/call', arguments: {
                'call': call,
                'channelName': call.callId,
              });
            }
          }
        }
      },
    );

    await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (Platform.isAndroid) {
      final androidPlugin = _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.requestNotificationsPermission();
    }
    final authService = AuthService();
    String? token = await _firebaseMessaging.getToken();
    if (token != null) {
      if (kDebugMode) {
        print("Device Token: $token");
      }
      // Save FCM token to Firestore for the current user
      final user = authService.currentUser!['user']['id']?.toString();
      if (user != null) {
        await _firestoreService.saveFcmToken(user, token);
      }
    } else {
      if (kDebugMode) {
        print("Failed to get device token");
      }
    }

    await _firebaseMessaging.subscribeToTopic('all');
    if (kDebugMode) {
      print("Subscribed to 'all' topic");
    }

    FirebaseMessaging.onBackgroundMessage(_backgroundMessageHandler);

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (kDebugMode) {
        print("Foreground Message Received: ${message.toMap()}");
        print(
            "Notification Field: ${message.notification?.title} - ${message.notification?.body}");
        print("Data Field: ${message.data}");
      }
      if (message.data.isNotEmpty) {
        _showNotification(message);
      } else if (message.notification != null) {
        _showNotificationFromNotificationField(message);
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      if (kDebugMode) {
        print(
            'App opened from notification: ${message.data['callId'] ?? message.notification?.title}');
      }
      // Handle app opened from notification
      if (message.data.containsKey('callId')) {
        final callId = message.data['callId'];
        _navigateToCallScreen(callId);
      }
    });

    RemoteMessage? initialMessage =
        await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) {
      if (kDebugMode) {
        print(
            'App opened from terminated state: ${initialMessage.data['callId'] ?? initialMessage.notification?.title}');
      }
      if (initialMessage.data.containsKey('callId')) {
        _navigateToCallScreen(initialMessage.data['callId']);
      }
    }
  }

  Future<String> getDeviceToken() async {
    String? token = await _firebaseMessaging.getToken();
    return token ?? '';
  }

  Future<void> saveCurrentUserFcmToken() async {
    final userId = await AuthService().getUserId();
    final fcmToken = await AuthService().getFcmToken();
    if (userId != null && fcmToken != null) {
      await _firestoreService.saveFcmToken(userId, fcmToken);
    }
  }

  // Send notification via Laravel backend
  Future<void> sendCallNotification(
      String receiverUid, String callerName, String callId) async {
    final receiver = await _firestoreService.getUser(receiverUid);
    final receiverFcmToken = receiver?.toMap()['fcm_token'];
    final token = await AuthService().getToken();
    if (receiverFcmToken == null) {
      throw Exception('Receiver FCM token not found');
    }
    final response = await http.post(
      Uri.parse('${Constants.laravelApiBaseUrl}/send-call-notification'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'receiver_fcm_token': receiverFcmToken,
        'caller_name': callerName,
        'call_id': callId,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to send call notification');
    }
  }

  static Future<void> _backgroundMessageHandler(RemoteMessage message) async {
    if (message.data.isNotEmpty) {
      await _showBackgroundNotification(message);
    } else if (message.notification != null) {
      await _showBackgroundNotificationFromNotificationField(message);
    }
  }

  static Future<void> _showBackgroundNotification(RemoteMessage message) async {
    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'call_channel',
      'Call Notifications',
      channelDescription: 'Notifications for incoming calls',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('notification'),
    );

    const DarwinNotificationDetails iOSDetails = DarwinNotificationDetails(
      sound: 'notification.mp3',
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iOSDetails,
    );

    await flutterLocalNotificationsPlugin.show(
      generate16BitId(),
      message.data['title'] ?? 'Incoming Call',
      message.data['body'] ?? 'You have an incoming call',
      notificationDetails,
      payload: 'call|${message.data['callId']}',
    );
  }

  Future<void> _showNotification(RemoteMessage message) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'call_channel',
      'Call Notifications',
      channelDescription: 'Notifications for incoming calls',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('notification'),
    );

    const DarwinNotificationDetails iOSDetails = DarwinNotificationDetails(
      sound: 'notification.mp3',
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iOSDetails,
    );

    await _flutterLocalNotificationsPlugin.show(
      generate16BitId(),
      message.data['title'] ?? 'Incoming Call',
      message.data['body'] ?? 'You have an incoming call',
      notificationDetails,
      payload: 'call|${message.data['callId']}',
    );
  }

  Future<void> _showNotificationFromNotificationField(
      RemoteMessage message) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'call_channel',
      'Call Notifications',
      channelDescription: 'Notifications for incoming calls',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('notification'),
    );

    const DarwinNotificationDetails iOSDetails = DarwinNotificationDetails(
      sound: 'notification.mp3',
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iOSDetails,
    );

    await _flutterLocalNotificationsPlugin.show(
      generate16BitId(),
      message.notification?.title ?? 'Incoming Call',
      message.notification?.body ?? 'You have an incoming call',
      notificationDetails,
      payload: 'call|${message.data['callId']}',
    );
  }

  static Future<void> _showBackgroundNotificationFromNotificationField(
      RemoteMessage message) async {
    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'call_channel',
      'Call Notifications',
      channelDescription: 'Notifications for incoming calls',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('notification'),
    );

    const DarwinNotificationDetails iOSDetails = DarwinNotificationDetails(
      sound: 'notification.mp3',
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iOSDetails,
    );

    await flutterLocalNotificationsPlugin.show(
      generate16BitId(),
      message.notification?.title ?? 'Incoming Call',
      message.notification?.body ?? 'You have an incoming call',
      notificationDetails,
      payload: 'call|${message.data['callId']}',
    );
  }

  void _createNotificationChannel() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'call_channel',
      'Call Notifications',
      description: 'Notifications for incoming calls',
      importance: Importance.high,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('notification'),
    );

    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  Future<void> _navigateToCallScreen(String callId) async {
    final callDoc = await _firestoreService.getCallStream(callId).first;
    if (callDoc.exists) {
      final call = CallModel.fromMap(callDoc.data() as Map<String, dynamic>);
      Get.toNamed('/call', arguments: {
        'call': call,
        'channelName': call.callId,
      });
    }
  }

  Future<void> showTestNotification() async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'call_channel',
      'Call Notifications',
      channelDescription: 'Notifications for incoming calls',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('notification'),
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
    );

    await _flutterLocalNotificationsPlugin.show(
      generate16BitId(),
      'Test Notification',
      'This is a test notification with custom sound',
      notificationDetails,
      payload: 'test',
    );
  }
}
