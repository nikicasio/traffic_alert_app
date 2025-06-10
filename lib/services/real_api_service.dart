import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/alert.dart';

class RealApiService {
  static const String baseUrl = 'http://159.69.41.118/api'; // Cloud server IP
  static const String _tokenKey = 'auth_token';
  
  String? _authToken;
  
  // Response caching with memory limits
  final Map<String, List<Alert>> _alertsCache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  static const Duration _cacheValidDuration = Duration(seconds: 10);
  static const int _maxCacheEntries = 50; // Limit memory usage
  
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

  // Check if API is reachable
  Future<bool> isApiReachable() async {
    try {
      final response = await http.head(
        Uri.parse(baseUrl),
      ).timeout(const Duration(seconds: 5));
      return response.statusCode < 500;
    } catch (e) {
      print('API unreachable: $e');
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
    print('🔍 DEBUG: Starting getNearbyAlerts...');
    print('🔍 DEBUG: Auth token present: ${_authToken != null}');
    print('🔍 DEBUG: Auth token length: ${_authToken?.length ?? 0}');
    print('🔍 DEBUG: Auth headers: $_headers');
    // Create cache key based on location and parameters
    final cacheKey = '${latitude.toStringAsFixed(3)}_${longitude.toStringAsFixed(3)}_${radius}_$type';
    
    // Check if we have cached data that's still valid
    final now = DateTime.now();
    _cleanupCache(); // Clean up expired entries
    
    if (_alertsCache.containsKey(cacheKey) && _cacheTimestamps.containsKey(cacheKey)) {
      final cacheTime = _cacheTimestamps[cacheKey]!;
      if (now.difference(cacheTime) < _cacheValidDuration) {
        print('🚀 Using cached alerts for $cacheKey (${now.difference(cacheTime).inSeconds}s old)');
        return _alertsCache[cacheKey]!;
      } else {
        print('⏰ Cache expired for $cacheKey, fetching fresh data');
      }
    }
    
    // Retry logic with exponential backoff
    int retryCount = 0;
    const maxRetries = 3;
    
    while (retryCount < maxRetries) {
      try {
        final queryParams = {
          'latitude': latitude.toString(),
          'longitude': longitude.toString(),
          'radius': radius.toString(),
        };
        
        if (type != null) queryParams['type'] = type;
        if (severity != null) queryParams['severity'] = severity.toString();

        final uri = Uri.parse('$baseUrl/alerts').replace(queryParameters: queryParams);
        final response = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 8));

        print('Get nearby alerts response: ${response.statusCode}');
        print('API URL: $uri');
        print('Authorization header present: ${_headers.containsKey('Authorization')}');
        print('🔍 DEBUG: Response body: ${response.body}');
        
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['success'] == true) {
            final alertsJson = data['alerts'] as List;
            print('📄 Raw API response contains ${alertsJson.length} alerts');
            
            final alerts = alertsJson.map((json) {
              try {
                final alert = Alert.fromJson(json);
                print('✅ Parsed alert: ID ${alert.id}, Type: ${alert.type}, Location: ${alert.latitude},${alert.longitude}');
                return alert;
              } catch (e) {
                print('❌ Failed to parse alert: $json - Error: $e');
                return null;
              }
            }).where((alert) => alert != null).cast<Alert>().toList();
            
            // Cache the successful response with memory management
            _alertsCache[cacheKey] = alerts;
            _cacheTimestamps[cacheKey] = now;
            
            // Prevent memory leaks by limiting cache size
            if (_alertsCache.length > _maxCacheEntries) {
              _cleanupOldestCacheEntries();
            }
            
            print('💾 Cached ${alerts.length} alerts for $cacheKey');
            print('🔄 Fresh API call returned ${alerts.length} alerts');
            
            return alerts;
          } else {
            print('Get alerts failed: ${data['message']}');
            return [];
          }
        } else {
          print('Get alerts failed: ${response.body}');
          return [];
        }
      } catch (e) {
        print('Get alerts error (attempt ${retryCount + 1}): $e');
        retryCount++;
        
        if (retryCount < maxRetries) {
          // Exponential backoff: wait 1s, 2s, 4s
          final delay = Duration(seconds: (1 << retryCount));
          print('Retrying in ${delay.inSeconds}s...');
          await Future.delayed(delay);
        }
      }
    }
    
    print('All retry attempts failed, returning empty alerts list');
    return [];
  }

  // Clear all alerts cache
  void _clearAlertsCache() {
    _alertsCache.clear();
    _cacheTimestamps.clear();
    print('🧹 Cleared all alerts cache');
  }

  // Public method to force refresh alerts (bypasses cache)
  Future<List<Alert>> refreshNearbyAlerts({
    required double latitude,
    required double longitude,
    int radius = 10000,
    String? type,
    int? severity,
  }) async {
    _clearAlertsCache();
    return getNearbyAlerts(
      latitude: latitude,
      longitude: longitude,
      radius: radius,
      type: type,
      severity: severity,
    );
  }

  // Public method to manually clear cache (for debugging/testing)
  void clearCache() {
    _clearAlertsCache();
  }
  
  // Force fresh fetch with cache clear (for immediate updates)
  Future<List<Alert>> forceFreshAlerts({
    required double latitude,
    required double longitude,
    int radius = 10000,
    String? type,
    int? severity,
  }) async {
    print('🚀 FORCE FRESH: Clearing cache and fetching alerts');
    _clearAlertsCache();
    return getNearbyAlerts(
      latitude: latitude,
      longitude: longitude,
      radius: radius,
      type: type,
      severity: severity,
    );
  }

  // Debug method to force fresh API call (bypasses all caching)
  Future<List<Alert>> debugFreshAlerts({
    required double latitude,
    required double longitude,
    int radius = 10000,
  }) async {
    try {
      print('🐛 DEBUG: Making fresh API call (no cache)');
      final queryParams = {
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
        'radius': radius.toString(),
      };

      final uri = Uri.parse('$baseUrl/alerts').replace(queryParameters: queryParams);
      final response = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 8));

      print('🐛 DEBUG: Response ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final alertsJson = data['alerts'] as List;
          print('🐛 DEBUG: Raw response has ${alertsJson.length} alerts');
          
          final alerts = alertsJson.map((json) => Alert.fromJson(json)).toList();
          print('🐛 DEBUG: Parsed ${alerts.length} alerts successfully');
          
          for (int i = 0; i < alerts.length; i++) {
            final alert = alerts[i];
            print('🐛 DEBUG Alert ${i + 1}: ID ${alert.id}, Type: ${alert.type}, Loc: ${alert.latitude},${alert.longitude}');
          }
          
          return alerts;
        }
      }
      
      print('🐛 DEBUG: API call failed');
      return [];
    } catch (e) {
      print('🐛 DEBUG: Error - $e');
      return [];
    }
  }

  // Clean up expired cache entries to prevent memory leaks
  void _cleanupCache() {
    final now = DateTime.now();
    final expiredKeys = <String>[];
    
    for (final entry in _cacheTimestamps.entries) {
      if (now.difference(entry.value) > _cacheValidDuration) {
        expiredKeys.add(entry.key);
      }
    }
    
    for (final key in expiredKeys) {
      _alertsCache.remove(key);
      _cacheTimestamps.remove(key);
    }
    
    if (expiredKeys.isNotEmpty) {
      print('🧹 Cleaned up ${expiredKeys.length} expired cache entries');
    }
  }

  // Clean up oldest cache entries to prevent memory leaks
  void _cleanupOldestCacheEntries() {
    if (_cacheTimestamps.length <= _maxCacheEntries) return;
    
    // Sort by timestamp and remove oldest entries
    final sortedEntries = _cacheTimestamps.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    
    final entriesToRemove = sortedEntries.take(_cacheTimestamps.length - _maxCacheEntries);
    
    for (final entry in entriesToRemove) {
      _alertsCache.remove(entry.key);
      _cacheTimestamps.remove(entry.key);
    }
    
    print('🧹 Removed ${entriesToRemove.length} oldest cache entries to free memory');
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
          // Clear cache to force refresh of nearby alerts
          _clearAlertsCache();
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
        // Clear cache to refresh alert counts and status
        _clearAlertsCache();
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

  Future<bool> updatePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/auth/profile'),
        headers: _headers,
        body: jsonEncode({
          'current_password': currentPassword,
          'password': newPassword,
          'password_confirmation': confirmPassword,
        }),
      );

      print('Update password response: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('Password updated: ${data['message']}');
        return true;
      } else {
        print('Update password failed: ${response.body}');
        return false;
      }
    } catch (e) {
      print('Update password error: $e');
      return false;
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

  Future<List<Map<String, dynamic>>> getUserReports() async {
    if (!isAuthenticated || _authToken == null) {
      throw Exception('User not authenticated');
    }

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/user/reports'),
        headers: _headers,
      );

      print('Get user reports response: ${response.statusCode}');
      print('Get user reports body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return List<Map<String, dynamic>>.from(data['reports'] ?? []);
        } else {
          print('Get user reports failed: ${data['message']}');
          throw Exception(data['message'] ?? 'Failed to get user reports');
        }
      } else {
        print('Failed to get user reports: ${response.body}');
        final data = jsonDecode(response.body);
        throw Exception(data['message'] ?? 'Failed to get user reports');
      }
    } catch (e) {
      print('Error getting user reports: $e');
      throw Exception('Failed to get user reports: $e');
    }
  }

  Future<bool> deleteAlert(int alertId) async {
    if (!isAuthenticated || _authToken == null) {
      throw Exception('User not authenticated');
    }

    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/alerts/$alertId'),
        headers: _headers,
      );

      print('Delete alert response: ${response.statusCode}');
      print('Delete alert body: ${response.body}');

      if (response.statusCode == 200) {
        return true;
      } else {
        print('Failed to delete alert: ${response.body}');
        return false;
      }
    } catch (e) {
      print('Error deleting alert: $e');
      throw Exception('Failed to delete alert: $e');
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

  // Health check with retry logic
  Future<bool> checkHealth({int maxRetries = 3}) async {
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        print('🏥 Health check attempt $attempt/$maxRetries');
        
        final response = await http.get(
          Uri.parse('$baseUrl/health'),
          headers: {'Accept': 'application/json'},
        ).timeout(const Duration(seconds: 10));

        print('Health check response: ${response.statusCode}');
        if (response.statusCode == 200) {
          return true;
        }
      } catch (e) {
        print('Health check error (attempt $attempt): $e');
        if (attempt < maxRetries) {
          await Future.delayed(Duration(seconds: attempt * 2)); // Exponential backoff
        }
      }
    }
    
    print('❌ Health check failed after $maxRetries attempts');
    return false;
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