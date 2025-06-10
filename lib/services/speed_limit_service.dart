import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;

class SpeedLimitService {
  static const String _overpassUrl = 'https://overpass-api.de/api/interpreter';
  static const Duration _cacheTimeout = Duration(minutes: 5);
  
  // Cache to avoid repeated requests for the same location
  final Map<String, SpeedLimitResult> _cache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  
  // Singleton pattern
  static final SpeedLimitService _instance = SpeedLimitService._internal();
  factory SpeedLimitService() => _instance;
  SpeedLimitService._internal();

  /// Get speed limit for current location
  /// Returns speed limit in km/h or null if not found
  Future<SpeedLimitResult?> getSpeedLimit(double latitude, double longitude, {double radiusMeters = 50}) async {
    final cacheKey = '${latitude.toStringAsFixed(4)}_${longitude.toStringAsFixed(4)}';
    
    // Check cache first
    if (_cache.containsKey(cacheKey) && _cacheTimestamps.containsKey(cacheKey)) {
      final cacheTime = _cacheTimestamps[cacheKey]!;
      if (DateTime.now().difference(cacheTime) < _cacheTimeout) {
        print('Speed limit cache hit for $cacheKey');
        return _cache[cacheKey];
      }
    }
    
    try {
      print('Fetching speed limit for coordinates: $latitude, $longitude');
      
      // Build Overpass QL query to find nearby roads with speed limits
      final query = '''
[out:json][timeout:10];
(
  way["highway"]["maxspeed"](around:$radiusMeters,$latitude,$longitude);
  way["highway"]["zone:maxspeed"](around:$radiusMeters,$latitude,$longitude);
);
out geom;
''';

      final response = await http.post(
        Uri.parse(_overpassUrl),
        headers: {'Content-Type': 'text/plain'},
        body: query,
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final elements = data['elements'] as List?;
        
        if (elements != null && elements.isNotEmpty) {
          final result = _parseSpeedLimitFromElements(elements, latitude, longitude);
          
          // Cache the result
          _cache[cacheKey] = result;
          _cacheTimestamps[cacheKey] = DateTime.now();
          
          print('Speed limit found: ${result.speedLimitKmh} km/h on ${result.roadType}');
          return result;
        }
      } else {
        print('Overpass API error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Error fetching speed limit: $e');
    }
    
    // Cache null result to avoid repeated failed requests
    final nullResult = SpeedLimitResult(
      speedLimitKmh: null,
      roadType: 'unknown',
      roadName: null,
      confidence: 0.0,
    );
    _cache[cacheKey] = nullResult;
    _cacheTimestamps[cacheKey] = DateTime.now();
    
    return nullResult;
  }

  SpeedLimitResult _parseSpeedLimitFromElements(List elements, double userLat, double userLon) {
    SpeedLimitResult? bestResult;
    double bestDistance = double.infinity;
    
    for (final element in elements) {
      if (element['type'] != 'way') continue;
      
      final tags = element['tags'] as Map<String, dynamic>?;
      if (tags == null) continue;
      
      // Extract speed limit
      int? speedLimit = _extractSpeedLimit(tags);
      if (speedLimit == null) continue;
      
      // Extract road information
      final highway = tags['highway'] as String?;
      final roadName = tags['name'] as String? ?? tags['ref'] as String?;
      
      // Calculate distance to road
      final geometry = element['geometry'] as List?;
      if (geometry != null && geometry.isNotEmpty) {
        double minDistance = double.infinity;
        
        for (final point in geometry) {
          final lat = point['lat'] as double;
          final lon = point['lon'] as double;
          final distance = _calculateDistance(userLat, userLon, lat, lon);
          if (distance < minDistance) {
            minDistance = distance;
          }
        }
        
        // Use the closest road
        if (minDistance < bestDistance) {
          bestDistance = minDistance;
          bestResult = SpeedLimitResult(
            speedLimitKmh: speedLimit,
            roadType: highway ?? 'unknown',
            roadName: roadName,
            confidence: _calculateConfidence(minDistance, highway),
          );
        }
      }
    }
    
    return bestResult ?? SpeedLimitResult(
      speedLimitKmh: null,
      roadType: 'unknown',
      roadName: null,
      confidence: 0.0,
    );
  }

  int? _extractSpeedLimit(Map<String, dynamic> tags) {
    // Check maxspeed tag first
    final maxspeed = tags['maxspeed'] as String?;
    if (maxspeed != null) {
      // Parse various formats: "50", "50 km/h", "50 mph", "none", "signals"
      final speedStr = maxspeed.toLowerCase().trim();
      
      if (speedStr == 'none' || speedStr == 'signals' || speedStr == 'variable') {
        return null; // No fixed speed limit
      }
      
      // Extract numeric value
      final match = RegExp(r'(\d+)').firstMatch(speedStr);
      if (match != null) {
        int speed = int.parse(match.group(1)!);
        
        // Convert mph to km/h if needed
        if (speedStr.contains('mph')) {
          speed = (speed * 1.60934).round();
        }
        
        return speed;
      }
    }
    
    // Check zone:maxspeed tag
    final zoneMaxspeed = tags['zone:maxspeed'] as String?;
    if (zoneMaxspeed != null) {
      final match = RegExp(r'(\d+)').firstMatch(zoneMaxspeed);
      if (match != null) {
        return int.parse(match.group(1)!);
      }
    }
    
    // Fallback to common speed limits based on road type
    final highway = tags['highway'] as String?;
    if (highway != null) {
      return _getDefaultSpeedLimit(highway);
    }
    
    return null;
  }

  int? _getDefaultSpeedLimit(String highway) {
    switch (highway) {
      case 'motorway':
        return 120; // Common motorway speed limit
      case 'trunk':
        return 100;
      case 'primary':
        return 80;
      case 'secondary':
        return 60;
      case 'tertiary':
        return 50;
      case 'residential':
        return 30;
      case 'living_street':
        return 20;
      case 'unclassified':
        return 50;
      default:
        return null;
    }
  }

  double _calculateConfidence(double distanceMeters, String? roadType) {
    // Higher confidence for closer roads
    double distanceConfidence = (50 - distanceMeters.clamp(0, 50)) / 50;
    
    // Higher confidence for major roads
    double roadConfidence = 0.5;
    if (roadType != null) {
      switch (roadType) {
        case 'motorway':
        case 'trunk':
        case 'primary':
          roadConfidence = 1.0;
          break;
        case 'secondary':
        case 'tertiary':
          roadConfidence = 0.8;
          break;
        case 'residential':
        case 'unclassified':
          roadConfidence = 0.6;
          break;
      }
    }
    
    return (distanceConfidence * 0.7 + roadConfidence * 0.3).clamp(0.0, 1.0);
  }

  // Calculate distance between two points in meters
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double p = 0.017453292519943295; // math.PI / 180
    final double a = 0.5 - 
      (math.cos((lat2 - lat1) * p) - 1) / 2 + 
      math.cos(lat1 * p) * math.cos(lat2 * p) * (1 - math.cos((lon2 - lon1) * p)) / 2;
    return 12742 * math.asin(math.sqrt(a)) * 1000; // 2 * R * asin(sqrt(a)) * 1000 for meters
  }

  // Clear cache (useful for testing or memory management)
  void clearCache() {
    _cache.clear();
    _cacheTimestamps.clear();
  }
}

class SpeedLimitResult {
  final int? speedLimitKmh;
  final String roadType;
  final String? roadName;
  final double confidence; // 0.0 to 1.0

  SpeedLimitResult({
    required this.speedLimitKmh,
    required this.roadType,
    required this.roadName,
    required this.confidence,
  });

  bool get hasSpeedLimit => speedLimitKmh != null;
  
  bool get isReliable => confidence > 0.7;

  @override
  String toString() {
    return 'SpeedLimitResult(speedLimit: $speedLimitKmh km/h, road: $roadType, name: $roadName, confidence: ${(confidence * 100).toStringAsFixed(1)}%)';
  }
}