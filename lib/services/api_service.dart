import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/alert.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  final String baseUrl;
  String? _deviceId;

  ApiService({required this.baseUrl});

  // Initialize and get/create device ID
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _deviceId = prefs.getString('device_id');
    
    if (_deviceId == null) {
      // Generate a new device ID if none exists
      _deviceId = DateTime.now().millisecondsSinceEpoch.toString();
      await prefs.setString('device_id', _deviceId!);
    }
  }

  // Get nearby alerts
  Future<List<Alert>> getNearbyAlerts(double lat, double lng, {double radius = 5000}) async {
    try {
      final uri = Uri.parse('$baseUrl/api/alerts')
          .replace(queryParameters: {
            'lat': lat.toString(),
            'lng': lng.toString(),
            'radius': radius.toString(),
          });
          
      print('Fetching alerts from: ${uri.toString()}');
      
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      
      print('Response status: ${response.statusCode}');
      if (response.statusCode != 200) {
        print('Response body: ${response.body}');
      }
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Alert.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load alerts: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Error getting alerts: $e');
      return [];
    }
  }

  // Get directional alerts (in driving direction)
  Future<List<Alert>> getDirectionalAlerts(
    double lat, 
    double lng, 
    double heading,
    {double radius = 5000, double angle = 60}
  ) async {
    try {
      final uri = Uri.parse('$baseUrl/api/directional-alerts')
          .replace(queryParameters: {
            'lat': lat.toString(),
            'lng': lng.toString(),
            'heading': heading.toString(),
            'radius': radius.toString(),
            'angle': angle.toString(),
          });
          
      print('Fetching directional alerts from: ${uri.toString()}');
      
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      
      print('Response status: ${response.statusCode}');
      if (response.statusCode != 200) {
        print('Response body: ${response.body}');
      }
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Alert.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load directional alerts: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Error getting directional alerts: $e');
      return [];
    }
  }

  // Report a new alert
  Future<Alert?> reportAlert(String type, double latitude, double longitude) async {
    try {
      if (_deviceId == null) await initialize();
      
      final uri = Uri.parse('$baseUrl/api/alerts');
      
      print('Reporting alert to: ${uri.toString()}');
      
      final payload = {
        'type': type,
        'latitude': latitude,
        'longitude': longitude,
        'reportedBy': _deviceId,
      };
      
      print('Alert payload: $payload');
      
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(payload),
      ).timeout(const Duration(seconds: 10));
      
      print('Response status: ${response.statusCode}');
      if (response.statusCode != 201) {
        print('Response body: ${response.body}');
      }
      
      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        
        return Alert(
          id: data['id'],
          type: type,
          latitude: latitude,
          longitude: longitude,
          reportedAt: DateTime.now(),
        );
      } else {
        throw Exception('Failed to report alert: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Error reporting alert: $e');
      return null;
    }
  }

  // Confirm an alert
  Future<bool> confirmAlert(int alertId) async {
    try {
      final uri = Uri.parse('$baseUrl/api/alerts/$alertId/confirm');
      
      print('Confirming alert at: ${uri.toString()}');
      
      final response = await http.post(uri).timeout(const Duration(seconds: 10));
      
      print('Response status: ${response.statusCode}');
      if (response.statusCode != 200) {
        print('Response body: ${response.body}');
      }
      
      return response.statusCode == 200;
    } catch (e) {
      print('Error confirming alert: $e');
      return false;
    }
  }

  // Dismiss an alert
  Future<bool> dismissAlert(int alertId) async {
    try {
      final uri = Uri.parse('$baseUrl/api/alerts/$alertId/dismiss');
      
      print('Dismissing alert at: ${uri.toString()}');
      
      final response = await http.post(uri).timeout(const Duration(seconds: 10));
      
      print('Response status: ${response.statusCode}');
      if (response.statusCode != 200) {
        print('Response body: ${response.body}');
      }
      
      return response.statusCode == 200;
    } catch (e) {
      print('Error dismissing alert: $e');
      return false;
    }
  }
}