import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/alert.dart';
import 'real_api_service.dart';

// Top-level function for background message handling
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('Handling a background message: ${message.messageId}');
  
  // Handle background notification
  if (message.data.isNotEmpty) {
    await NotificationService._handleBackgroundMessage(message);
  }
}

class NotificationService {
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final RealApiService _apiService = RealApiService();
  
  static const String _fcmTokenKey = 'fcm_token';
  String? _currentToken;
  
  // Singleton pattern
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();
  
  Future<void> initialize() async {
    // Initialize Firebase
    await Firebase.initializeApp();
    
    // Initialize local notifications
    const AndroidInitializationSettings androidSettings = 
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const DarwinInitializationSettings iosSettings = 
        DarwinInitializationSettings(
          requestSoundPermission: true,
          requestBadgePermission: true,
          requestAlertPermission: true,
        );
    
    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    
    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _handleNotificationTap,
    );
    
    // Initialize FCM
    await _initializeFCM();
  }
  
  Future<void> showAlertNotification(Alert alert) async {
    String title;
    String body;
    
    // Create notification content based on alert type
    switch (alert.type) {
      case 'accident':
        title = 'Accident Ahead';
        body = 'There is an accident ${_formatDistance(alert.distance)} ahead on your route';
        break;
      case 'fire':
        title = 'Fire Reported Ahead';
        body = 'Fire reported ${_formatDistance(alert.distance)} ahead on your route';
        break;
      case 'police':
        title = 'Speed Trap Alert';
        body = 'Police speed check ${_formatDistance(alert.distance)} ahead';
        break;
      case 'blocked_road':
        title = 'Road Blocked Ahead';
        body = 'Road blockage ${_formatDistance(alert.distance)} ahead on your route';
        break;
      case 'traffic':
        title = 'Traffic Congestion';
        body = 'Heavy traffic ${_formatDistance(alert.distance)} ahead';
        break;
      default:
        title = 'Alert Ahead';
        body = 'There is an alert ${_formatDistance(alert.distance)} ahead on your route';
    }
    
    // Create the notification details
    AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'traffic_alerts',
      'Traffic Alerts',
      channelDescription: 'Notifications for traffic incidents',
      importance: Importance.high,
      priority: Priority.high,
      enableVibration: true,
    );
    
    DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    
    NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    
    // Show the notification
    await _notifications.show(
      alert.id ?? DateTime.now().millisecondsSinceEpoch.hashCode,
      title,
      body,
      details,
    );
  }
  
  String _formatDistance(double? distance) {
    if (distance == null) return '';
    
    if (distance < 1000) {
      return '${distance.round()} meters';
    } else {
      return '${(distance / 1000).toStringAsFixed(1)} km';
    }
  }
  
  // FCM Initialization
  Future<void> _initializeFCM() async {
    try {
      // Request permission for notifications
      NotificationSettings settings = await _firebaseMessaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
      
      print('FCM permission granted: ${settings.authorizationStatus}');
      
      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        
        // Get the token
        await _refreshFCMToken();
        
        // Listen for token refresh
        _firebaseMessaging.onTokenRefresh.listen(_handleTokenRefresh);
        
        // Set up foreground message handling
        FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
        
        // Set up background message handling
        FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
        
        // Handle notification opened app
        FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationOpenedApp);
        
        // Check if app was opened from a notification
        RemoteMessage? initialMessage = await _firebaseMessaging.getInitialMessage();
        if (initialMessage != null) {
          _handleNotificationOpenedApp(initialMessage);
        }
        
        print('FCM initialized successfully');
      }
    } catch (e) {
      print('Error initializing FCM: $e');
    }
  }
  
  // FCM Token Management
  Future<void> _refreshFCMToken() async {
    try {
      String? token = await _firebaseMessaging.getToken();
      if (token != null && token != _currentToken) {
        _currentToken = token;
        await _storeFCMToken(token);
        await _sendTokenToServer(token);
        print('FCM token refreshed: $token');
      }
    } catch (e) {
      print('Error refreshing FCM token: $e');
    }
  }
  
  Future<void> _handleTokenRefresh(String token) async {
    _currentToken = token;
    await _storeFCMToken(token);
    await _sendTokenToServer(token);
    print('FCM token updated: $token');
  }
  
  Future<void> _storeFCMToken(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_fcmTokenKey, token);
    } catch (e) {
      print('Error storing FCM token: $e');
    }
  }
  
  Future<String?> _getStoredFCMToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_fcmTokenKey);
    } catch (e) {
      print('Error getting stored FCM token: $e');
      return null;
    }
  }
  
  Future<void> _sendTokenToServer(String token) async {
    try {
      if (_apiService.isAuthenticated) {
        await _apiService.updateDeviceToken(token);
        print('FCM token sent to server successfully');
      } else {
        print('User not authenticated, will send token after login');
      }
    } catch (e) {
      print('Error sending FCM token to server: $e');
    }
  }
  
  // Message Handlers
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    print('Got a message whilst in the foreground!');
    print('Message data: ${message.data}');
    
    if (message.notification != null) {
      print('Message also contained a notification: ${message.notification}');
    }
    
    // Show local notification for foreground messages
    await _showFCMNotification(message);
  }
  
  static Future<void> _handleBackgroundMessage(RemoteMessage message) async {
    print('Handling background message: ${message.messageId}');
    
    // Create a temporary instance for background processing
    final notificationService = NotificationService();
    await notificationService._showFCMNotification(message);
  }
  
  Future<void> _handleNotificationOpenedApp(RemoteMessage message) async {
    print('A new onMessageOpenedApp event was published!');
    print('Message data: ${message.data}');
    
    // Handle notification tap - could navigate to specific alert
    if (message.data.containsKey('alert_id')) {
      // Navigate to alert details or map view
      print('Opened app from notification for alert: ${message.data['alert_id']}');
    }
  }
  
  void _handleNotificationTap(NotificationResponse response) {
    print('Notification tapped: ${response.payload}');
    
    if (response.payload != null) {
      try {
        final data = jsonDecode(response.payload!);
        if (data['alert_id'] != null) {
          // Handle navigation to specific alert
          print('Tapped notification for alert: ${data['alert_id']}');
        }
      } catch (e) {
        print('Error parsing notification payload: $e');
      }
    }
  }
  
  // Show FCM notification as local notification
  Future<void> _showFCMNotification(RemoteMessage message) async {
    try {
      String title = message.notification?.title ?? 'Traffic Alert';
      String body = message.notification?.body ?? 'New traffic alert in your area';
      
      // Extract alert data if available
      if (message.data.isNotEmpty) {
        final alertType = message.data['alert_type'];
        final distance = message.data['distance'];
        
        if (alertType != null) {
          title = _getAlertTitle(alertType);
        }
        
        if (distance != null) {
          final distanceNum = double.tryParse(distance.toString());
          if (distanceNum != null) {
            body = '$body ${_formatDistance(distanceNum)} ahead';
          }
        }
      }
      
      AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'traffic_alerts_fcm',
        'Traffic Alerts (Push)',
        channelDescription: 'Push notifications for traffic incidents',
        importance: Importance.high,
        priority: Priority.high,
        enableVibration: true,
        playSound: true,
      );
      
      DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );
      
      NotificationDetails details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );
      
      // Create payload with alert data
      String payload = jsonEncode(message.data);
      
      await _notifications.show(
        message.hashCode,
        title,
        body,
        details,
        payload: payload,
      );
    } catch (e) {
      print('Error showing FCM notification: $e');
    }
  }
  
  String _getAlertTitle(String alertType) {
    switch (alertType) {
      case 'accident':
        return 'Accident Ahead';
      case 'fire':
        return 'Fire Reported Ahead';
      case 'police':
        return 'Speed Trap Alert';
      case 'blocked_road':
        return 'Road Blocked Ahead';
      case 'traffic':
        return 'Traffic Congestion';
      case 'roadwork':
        return 'Roadwork Ahead';
      case 'obstacle':
        return 'Obstacle on Road';
      default:
        return 'Traffic Alert';
    }
  }
  
  // Public methods
  Future<String?> getFCMToken() async {
    return _currentToken ?? await _getStoredFCMToken();
  }
  
  Future<void> updateTokenOnServer() async {
    final token = await getFCMToken();
    if (token != null) {
      await _sendTokenToServer(token);
    }
  }
  
  Future<bool> sendTestNotification() async {
    try {
      return await _apiService.sendTestNotification();
    } catch (e) {
      print('Error sending test notification: $e');
      return false;
    }
  }
}