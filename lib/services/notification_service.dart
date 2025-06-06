import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/alert.dart';

class NotificationService {
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  
  Future<void> initialize() async {
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
    
    await _notifications.initialize(initSettings);
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
}