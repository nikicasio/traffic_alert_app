import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/alert.dart';

class RealApiService {
  static const String baseUrl = 'http://localhost:8000/api'; // Local backend server
  static const String _tokenKey = 'auth_token';
  
  String? _authToken;
  
  // Singleton pattern
  static final RealApiService _instance = RealApiService._internal();
  factory RealApiService() => _instance;
  RealApiService._internal();

  // Initialize and load stored token
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _authToken = prefs.getString(_tokenKey);
    print('RealApiService initialized with token: ${_authToken != null ? "present" : "none"}');
  }

  // Get headers with authentication
  Map<String, String> get _headers {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    
    if (_authToken != null) {
      headers['Authorization'] = 'Bearer $_authToken';
    }
    
    return headers;
  }

  // Authentication endpoints
  Future<Map<String, dynamic>?> register({
    required String email,
    required String username,
    required String password,
    required String passwordConfirmation,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/register'),
        headers: _headers,
        body: jsonEncode({
          'email': email,
          'username': username,
          'password': password,
          'password_confirmation': passwordConfirmation,
        }),
      );

      print('Register response: ${response.statusCode}');
      
      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          await _storeToken(data['token']);
          return data;
        } else {
          print('Register failed: ${data['message']}');
          return null;
        }
      } else {
        print('Register failed: ${response.body}');
        return null;
      }
    } catch (e) {
      print('Register error: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> login({
    required String email,
    required String password,
    String? deviceToken,
  }) async {
    try {
      final body = {
        'email': email,
        'password': password,
      };
      
      if (deviceToken != null) {
        body['device_token'] = deviceToken;
      }

      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: _headers,
        body: jsonEncode(body),
      );

      print('Login response: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          await _storeToken(data['token']);
          return data;
        } else {
          print('Login failed: ${data['message']}');
          return null;
        }
      } else {
        print('Login failed: ${response.body}');
        return null;
      }
    } catch (e) {
      print('Login error: $e');
      return null;
    }
  }

  Future<bool> logout() async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/logout'),
        headers: _headers,
      );

      await _clearToken();
      return response.statusCode == 200;
    } catch (e) {
      print('Logout error: $e');
      await _clearToken(); // Clear token anyway
      return false;
    }
  }

  // Alert endpoints
  Future<List<Alert>> getNearbyAlerts({
    required double latitude,
    required double longitude,
    int radius = 10000,
    String? type,
    int? severity,
  }) async {
    try {
      final queryParams = {
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
        'radius': radius.toString(),
      };
      
      if (type != null) queryParams['type'] = type;
      if (severity != null) queryParams['severity'] = severity.toString();

      final uri = Uri.parse('$baseUrl/alerts').replace(queryParameters: queryParams);
      final response = await http.get(uri, headers: _headers);

      print('Get nearby alerts response: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final alertsJson = data['alerts'] as List;
          return alertsJson.map((json) => Alert.fromJson(json)).toList();
        } else {
          print('Get alerts failed: ${data['message']}');
          return [];
        }
      } else {
        print('Get alerts failed: ${response.body}');
        return [];
      }
    } catch (e) {
      print('Get alerts error: $e');
      return [];
    }
  }

  Future<List<Alert>> getDirectionalAlerts({
    required double latitude,
    required double longitude,
    required double heading,
    int radius = 2000,
    int angle = 60,
  }) async {
    try {
      final queryParams = {
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
        'heading': heading.toString(),
        'radius': radius.toString(),
        'angle': angle.toString(),
      };

      final uri = Uri.parse('$baseUrl/alerts/directional').replace(queryParameters: queryParams);
      final response = await http.get(uri, headers: _headers);

      print('Get directional alerts response: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final alertsJson = data['alerts'] as List;
          return alertsJson.map((json) => Alert.fromJson(json)).toList();
        } else {
          print('Get directional alerts failed: ${data['message']}');
          return [];
        }
      } else {
        print('Get directional alerts failed: ${response.body}');
        return [];
      }
    } catch (e) {
      print('Get directional alerts error: $e');
      return [];
    }
  }

  Future<Alert?> reportAlert({
    required String type,
    required double latitude,
    required double longitude,
    int? severity,
    String? description,
  }) async {
    try {
      final body = {
        'type': type,
        'latitude': latitude,
        'longitude': longitude,
      };
      
      if (severity != null) body['severity'] = severity;
      if (description != null) body['description'] = description;

      final response = await http.post(
        Uri.parse('$baseUrl/alerts'),
        headers: _headers,
        body: jsonEncode(body),
      );

      print('Report alert response: ${response.statusCode}');
      
      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return Alert.fromJson(data['alert']);
        } else {
          print('Report alert failed: ${data['message']}');
          return null;
        }
      } else {
        print('Report alert failed: ${response.body}');
        return null;
      }
    } catch (e) {
      print('Report alert error: $e');
      return null;
    }
  }

  Future<bool> confirmAlert({
    required String alertId,
    required String confirmationType, // 'confirmed', 'dismissed', 'not_there'
    String? comment,
  }) async {
    try {
      final body = {
        'confirmation_type': confirmationType,
      };
      
      if (comment != null) body['comment'] = comment;

      final response = await http.post(
        Uri.parse('$baseUrl/alerts/$alertId/confirm'),
        headers: _headers,
        body: jsonEncode(body),
      );

      print('Confirm alert response: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('Alert confirmed: ${data['message']}');
        return true;
      } else {
        print('Confirm alert failed: ${response.body}');
        return false;
      }
    } catch (e) {
      print('Confirm alert error: $e');
      return false;
    }
  }

  // User endpoints
  Future<Map<String, dynamic>?> getUserProfile() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/auth/profile'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['user'];
      } else {
        print('Get profile failed: ${response.body}');
        return null;
      }
    } catch (e) {
      print('Get profile error: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getUserStats() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/users/stats'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['stats'];
      } else {
        print('Get user stats failed: ${response.body}');
        return null;
      }
    } catch (e) {
      print('Get user stats error: $e');
      return null;
    }
  }

  // Geospatial endpoints
  Future<List<Map<String, dynamic>>> getAlertClusters({
    required double latitude,
    required double longitude,
    int radiusKm = 50,
    int minPoints = 3,
  }) async {
    try {
      final queryParams = {
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
        'radius_km': radiusKm.toString(),
        'min_points': minPoints.toString(),
      };

      final uri = Uri.parse('$baseUrl/geospatial/clusters').replace(queryParameters: queryParams);
      final response = await http.get(uri, headers: _headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['clusters']);
      } else {
        print('Get clusters failed: ${response.body}');
        return [];
      }
    } catch (e) {
      print('Get clusters error: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getTrafficHeatmap({
    required double latitude,
    required double longitude,
    int radiusKm = 10,
    int gridSize = 20,
  }) async {
    try {
      final queryParams = {
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
        'radius_km': radiusKm.toString(),
        'grid_size': gridSize.toString(),
      };

      final uri = Uri.parse('$baseUrl/geospatial/heatmap').replace(queryParameters: queryParams);
      final response = await http.get(uri, headers: _headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['heatmap']);
      } else {
        print('Get heatmap failed: ${response.body}');
        return [];
      }
    } catch (e) {
      print('Get heatmap error: $e');
      return [];
    }
  }

  // Notification endpoints
  Future<bool> updateDeviceToken(String deviceToken) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/notifications/device-token'),
        headers: _headers,
        body: jsonEncode({
          'device_token': deviceToken,
          'action': 'add',
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Update device token error: $e');
      return false;
    }
  }

  Future<bool> sendTestNotification() async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/notifications/test'),
        headers: _headers,
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Send test notification error: $e');
      return false;
    }
  }

  // Health check
  Future<bool> checkHealth() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/health'),
        headers: {'Accept': 'application/json'},
      );

      print('Health check response: ${response.statusCode}');
      return response.statusCode == 200;
    } catch (e) {
      print('Health check error: $e');
      return false;
    }
  }

  // Token management
  Future<void> _storeToken(String token) async {
    _authToken = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    print('Token stored');
  }

  Future<void> _clearToken() async {
    _authToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    print('Token cleared');
  }

  bool get isAuthenticated => _authToken != null;
  String? get authToken => _authToken;
}