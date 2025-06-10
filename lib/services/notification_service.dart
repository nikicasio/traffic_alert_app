import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/alert.dart';
import 'real_api_service.dart';

class NotificationService {
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  final RealApiService _apiService = RealApiService();
  
  // Singleton pattern
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();
  
  Future<void> initialize() async {
    // Initialize local notifications only
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
    
    // Request notification permissions for Android 13+ and iOS
    await _requestNotificationPermissions();
    
    print('Local notifications initialized successfully');
  }
  
  Future<void> _requestNotificationPermissions() async {
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    
    if (androidImplementation != null) {
      final bool? result = await androidImplementation.requestPermission();
      print('Android notification permission: ${result != null && result ? "granted" : "denied"}');
    }
    
    // For iOS, permissions are requested automatically during initialization
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
  
  // Placeholder methods for future Firebase integration
  Future<String?> getFCMToken() async {
    print('FCM not available - using local notifications only');
    return null;
  }
  
  Future<void> updateTokenOnServer() async {
    print('FCM not available - token update skipped');
  }
  
  Future<bool> sendTestNotification() async {
    try {
      // Send a test local notification instead
      await showTestNotification();
      return true;
    } catch (e) {
      print('Error sending test notification: $e');
      return false;
    }
  }
  
  Future<void> showTestNotification() async {
    AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'test_notifications',
      'Test Notifications',
      channelDescription: 'Test notifications',
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
    
    await _notifications.show(
      999,
      'Test Notification',
      'This is a test notification from RadarAlert',
      details,
    );
  }
}