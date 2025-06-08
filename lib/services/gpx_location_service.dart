import 'dart:async';
import 'dart:math';
import 'package:location/location.dart';
import 'package:latlong2/latlong.dart';

class GpxLocationService {
  static final GpxLocationService _instance = GpxLocationService._internal();
  factory GpxLocationService() => _instance;
  GpxLocationService._internal();

  final _locationController = StreamController<LocationData>.broadcast();
  final _headingController = StreamController<double>.broadcast();
  
  Stream<LocationData> get locationStream => _locationController.stream;
  Stream<double> get headingStream => _headingController.stream;

  LocationData? _currentLocation;
  double _currentHeading = 0.0;
  double _currentSpeed = 0.0;
  Timer? _updateTimer;
  
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;
  
  // GPX route points from the provided file (Aachen, Germany route)
  final List<LatLng> _routePoints = [
    LatLng(50.7440057, 6.1726622),
    LatLng(50.74399, 6.17267),
    LatLng(50.74391, 6.17269),
    LatLng(50.74388, 6.1727),
    LatLng(50.74379, 6.17273),
    LatLng(50.74373, 6.17274),
    LatLng(50.74368, 6.17274),
    LatLng(50.74364, 6.17274),
    LatLng(50.74356, 6.17273),
    LatLng(50.74348, 6.17272),
    LatLng(50.74341, 6.17269),
    LatLng(50.74338, 6.17268),
    LatLng(50.74335, 6.17267),
    LatLng(50.74327, 6.17261),
    LatLng(50.74323, 6.17254),
    LatLng(50.74318, 6.17249),
    LatLng(50.74316, 6.17244),
    LatLng(50.74312, 6.17237),
    LatLng(50.74309, 6.17228),
    LatLng(50.74302, 6.17212),
    LatLng(50.74297, 6.17199),
    LatLng(50.74295, 6.17195),
    LatLng(50.74289, 6.1718),
    LatLng(50.74282, 6.17164),
    LatLng(50.74275, 6.17146),
    LatLng(50.74258, 6.17104),
    LatLng(50.74252, 6.17091),
    LatLng(50.74248, 6.1708),
    LatLng(50.74244, 6.1707),
    LatLng(50.74239, 6.17059),
    LatLng(50.74231, 6.17043),
    LatLng(50.74227, 6.17034),
    LatLng(50.74225, 6.1703),
    LatLng(50.74218, 6.17018),
    LatLng(50.74215, 6.17013),
    LatLng(50.74212, 6.17007),
    LatLng(50.7421, 6.17003),
    LatLng(50.74209, 6.16998),
    LatLng(50.74208, 6.16995),
    LatLng(50.74209, 6.16992),
    LatLng(50.7421, 6.16988),
    LatLng(50.74212, 6.16986),
    LatLng(50.74214, 6.16985),
    LatLng(50.74216, 6.16985),
    LatLng(50.74218, 6.16985),
    LatLng(50.74221, 6.16987),
    LatLng(50.74222, 6.1699),
    LatLng(50.74226, 6.16998),
    LatLng(50.74228, 6.17003),
    LatLng(50.7423, 6.17008),
    LatLng(50.74232, 6.17014),
    LatLng(50.74235, 6.17018),
    LatLng(50.74237, 6.17021),
    LatLng(50.74242, 6.17026),
    LatLng(50.7425, 6.17035),
    LatLng(50.74258, 6.17041),
    LatLng(50.74265, 6.17048),
    LatLng(50.74273, 6.17055),
    LatLng(50.7428, 6.17062),
    LatLng(50.74288, 6.17069),
    LatLng(50.74295, 6.17074),
    LatLng(50.74303, 6.17078),
    LatLng(50.74311, 6.17081),
    LatLng(50.74315, 6.17083),
    LatLng(50.74316, 6.17083),
    LatLng(50.74321, 6.17085),
    LatLng(50.74326, 6.17085),
    LatLng(50.74331, 6.17085),
    LatLng(50.74335, 6.17085),
    LatLng(50.74339, 6.17085),
    LatLng(50.74341, 6.17085),
    LatLng(50.74345, 6.17082),
    LatLng(50.74349, 6.17078),
    LatLng(50.74352, 6.17075),
    LatLng(50.74355, 6.17073),
    LatLng(50.74357, 6.1707),
    LatLng(50.74359, 6.17066),
    LatLng(50.7436, 6.1706),
    LatLng(50.743602, 6.1705954),
    LatLng(50.74364, 6.17063),
    LatLng(50.74367, 6.17065),
    LatLng(50.74375, 6.17067),
    LatLng(50.74381, 6.17068),
    LatLng(50.74386, 6.17067),
    LatLng(50.74392, 6.17065),
    LatLng(50.74396, 6.17061),
    LatLng(50.74401, 6.17056),
    LatLng(50.74408, 6.17047),
    LatLng(50.74419, 6.17032),
    LatLng(50.74425, 6.17023),
    LatLng(50.74437, 6.17005),
    LatLng(50.74452, 6.16985),
    LatLng(50.74453, 6.16984),
    LatLng(50.74467, 6.16964),
    LatLng(50.74478, 6.16946),
    LatLng(50.74481, 6.16943),
    LatLng(50.74483, 6.16939),
    LatLng(50.74487, 6.16934),
    LatLng(50.7449, 6.1693),
    LatLng(50.74493, 6.16924),
    LatLng(50.74496, 6.16918),
    LatLng(50.745, 6.16908),
    LatLng(50.74518, 6.16867),
    LatLng(50.7454, 6.16817),
    LatLng(50.74548, 6.16799),
    LatLng(50.7455, 6.16793),
    LatLng(50.74561, 6.1677),
    LatLng(50.7457, 6.16751),
    LatLng(50.74607, 6.16669),
    LatLng(50.74616, 6.16647),
    LatLng(50.74621, 6.16635),
    LatLng(50.74625, 6.16624),
    LatLng(50.74634, 6.16599),
    LatLng(50.74639, 6.16583),
    LatLng(50.74642, 6.16571),
    LatLng(50.7464184, 6.1657089),
    // Adding more key points from the route (truncated for brevity)
    LatLng(50.74688, 6.16615),
    LatLng(50.74776, 6.16641),
    LatLng(50.74832, 6.16699),
    LatLng(50.74872, 6.16615),
    LatLng(50.74915, 6.1651),
    LatLng(50.7499, 6.16338),
    LatLng(50.75078, 6.16141),
    LatLng(50.75138, 6.16009),
    LatLng(50.75195, 6.15877),
    LatLng(50.75285, 6.15675),
    LatLng(50.75385, 6.15448),
    LatLng(50.7545, 6.153),
    LatLng(50.75521, 6.15142),
    LatLng(50.75591, 6.14985),
    LatLng(50.75669, 6.14808),
    LatLng(50.7572, 6.14702),
    LatLng(50.75781, 6.14563),
    LatLng(50.75831, 6.1445),
    LatLng(50.75918, 6.14248),
    LatLng(50.76023, 6.14007),
    LatLng(50.76158, 6.137),
    LatLng(50.76292, 6.13401),
    LatLng(50.76418, 6.13115),
    LatLng(50.7651, 6.1291),
    LatLng(50.76608, 6.12699),
    LatLng(50.76708, 6.12462),
    LatLng(50.76789, 6.12283),
    LatLng(50.76895, 6.12034),
    LatLng(50.77011, 6.11777),
    LatLng(50.77088, 6.11611),
    LatLng(50.77168, 6.1143),
    LatLng(50.77252, 6.11236),
    LatLng(50.77308, 6.11098),
    LatLng(50.77389, 6.10918),
    LatLng(50.77443, 6.10713),
    LatLng(50.77448, 6.10523),
    LatLng(50.77459, 6.09999),
    LatLng(50.7746, 6.09942),
    LatLng(50.77465, 6.09617),
    LatLng(50.77396, 6.09599),
    LatLng(50.7727, 6.09579),
    LatLng(50.77158, 6.09561),
    LatLng(50.77046, 6.09539),
    LatLng(50.76958, 6.09497),
    LatLng(50.76977, 6.0945),
    LatLng(50.769845, 6.0941718), // Destination
  ];
  
  int _currentRouteIndex = 0;
  final Random _random = Random();

  LocationData? get currentLocation => _currentLocation;
  double get currentHeading => _currentHeading;

  Future<void> initialize() async {
    if (_isInitialized) return;

    // Start at first route point
    final startPoint = _routePoints[0];
    
    _currentLocation = LocationData.fromMap({
      'latitude': startPoint.latitude,
      'longitude': startPoint.longitude,
      'accuracy': 3.0,
      'altitude': 400.0,
      'speed': 0.0, // m/s
      'speedAccuracy': 0.5,
      'heading': 0.0,
      'time': DateTime.now().millisecondsSinceEpoch.toDouble(),
    });

    _isInitialized = true;
    _locationController.add(_currentLocation!);
    _startGpxSimulation();
  }

  void _startGpxSimulation() {
    // Update every 2 seconds for smooth movement
    _updateTimer = Timer.periodic(Duration(seconds: 2), (timer) {
      _updateGpxLocation();
    });
  }

  void _updateGpxLocation() {
    if (_currentLocation == null || _currentRouteIndex >= _routePoints.length - 1) {
      // Restart route when finished
      _currentRouteIndex = 0;
      return;
    }

    // Get current and next route points
    final currentPoint = _routePoints[_currentRouteIndex];
    final nextPoint = _routePoints[_currentRouteIndex + 1];
    
    // Calculate heading based on direction to next point
    _currentHeading = _calculateBearing(currentPoint, nextPoint);
    
    // Calculate distance to next point
    final Distance distance = Distance();
    final distanceToNext = distance.as(LengthUnit.Meter, currentPoint, nextPoint);
    
    // Simulate highway/fast road driving speed (70-100 km/h as requested)
    // Add some variation for realistic highway driving
    double targetSpeedKmh = 70 + _random.nextDouble() * 30; // 70-100 km/h
    targetSpeedKmh = targetSpeedKmh.clamp(70, 100); // Ensure range 70-100 km/h
    
    // Occasionally slow down (traffic, construction, etc.)
    if (_random.nextDouble() < 0.08) {
      targetSpeedKmh *= 0.6; // Slow down for highway traffic (still faster than city)
    }
    
    _currentSpeed = targetSpeedKmh;
    double speedMs = targetSpeedKmh / 3.6; // Convert to m/s
    
    // Move towards next point
    // Calculate how far we move in 2 seconds at current speed
    double moveDistance = speedMs * 2; // 2 second intervals
    
    // If we're close to the next point, jump to it and advance
    if (distanceToNext <= moveDistance * 1.5) {
      _currentRouteIndex++;
      if (_currentRouteIndex < _routePoints.length) {
        final newPoint = _routePoints[_currentRouteIndex];
        _currentLocation = LocationData.fromMap({
          'latitude': newPoint.latitude,
          'longitude': newPoint.longitude,
          'accuracy': 2.0 + _random.nextDouble() * 2,
          'altitude': 400.0 + _random.nextDouble() * 10,
          'speed': speedMs,
          'speedAccuracy': 0.5,
          'heading': _currentHeading,
          'time': DateTime.now().millisecondsSinceEpoch.toDouble(),
        });
      }
    } else {
      // Interpolate position between current and next point
      double progress = moveDistance / distanceToNext;
      progress = progress.clamp(0.0, 1.0);
      
      double newLat = currentPoint.latitude + 
          (nextPoint.latitude - currentPoint.latitude) * progress;
      double newLng = currentPoint.longitude + 
          (nextPoint.longitude - currentPoint.longitude) * progress;
      
      // Add slight GPS noise but keep it realistic
      newLat += (_random.nextDouble() - 0.5) * 0.000002;
      newLng += (_random.nextDouble() - 0.5) * 0.000002;
      
      _currentLocation = LocationData.fromMap({
        'latitude': newLat,
        'longitude': newLng,
        'accuracy': 2.0 + _random.nextDouble() * 2,
        'altitude': 400.0 + _random.nextDouble() * 10,
        'speed': speedMs,
        'speedAccuracy': 0.5,
        'heading': _currentHeading,
        'time': DateTime.now().millisecondsSinceEpoch.toDouble(),
      });
    }

    _locationController.add(_currentLocation!);
    _headingController.add(_currentHeading);
  }

  double _calculateBearing(LatLng start, LatLng end) {
    final double startLatRad = start.latitude * (pi / 180);
    final double startLngRad = start.longitude * (pi / 180);
    final double endLatRad = end.latitude * (pi / 180);
    final double endLngRad = end.longitude * (pi / 180);

    final double deltaLng = endLngRad - startLngRad;

    final double x = sin(deltaLng) * cos(endLatRad);
    final double y = cos(startLatRad) * sin(endLatRad) - 
                     sin(startLatRad) * cos(endLatRad) * cos(deltaLng);

    double bearing = atan2(x, y);
    bearing = bearing * (180 / pi); // Convert to degrees
    bearing = (bearing + 360) % 360; // Normalize to 0-360

    return bearing;
  }

  Future<LocationData> getLocation() async {
    if (!_isInitialized) await initialize();
    return _currentLocation!;
  }

  void dispose() {
    _updateTimer?.cancel();
    _locationController.close();
    _headingController.close();
    _isInitialized = false;
  }
}