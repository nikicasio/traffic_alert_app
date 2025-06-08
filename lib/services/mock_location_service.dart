import 'dart:async';
import 'dart:math';
import 'package:location/location.dart';

class MockLocationService {
  static final MockLocationService _instance = MockLocationService._internal();
  factory MockLocationService() => _instance;
  MockLocationService._internal();

  final _locationController = StreamController<LocationData>.broadcast();
  final _headingController = StreamController<double>.broadcast();
  
  Stream<LocationData> get locationStream => _locationController.stream;
  Stream<double> get headingStream => _headingController.stream;

  LocationData? _currentLocation;
  double _currentHeading = 0.0;
  double _currentSpeed = 0.0;
  Timer? _updateTimer;
  final Random _random = Random();

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  LocationData? get currentLocation => _currentLocation;
  double get currentHeading => _currentHeading;

  Future<void> initialize() async {
    if (_isInitialized) return;

    _currentLocation = LocationData.fromMap({
      'latitude': 48.7758 + (_random.nextDouble() - 0.5) * 0.001,
      'longitude': 9.1829 + (_random.nextDouble() - 0.5) * 0.001,
      'accuracy': 5.0,
      'altitude': 400.0,
      'speed': _currentSpeed,
      'speedAccuracy': 1.0,
      'heading': _currentHeading,
      'time': DateTime.now().millisecondsSinceEpoch.toDouble(),
    });

    _isInitialized = true;
    _locationController.add(_currentLocation!);
    _startMockUpdates();
  }

  void _startMockUpdates() {
    _updateTimer = Timer.periodic(Duration(seconds: 2), (timer) {
      _updateMockLocation();
      _updateMockHeading();
      _updateMockSpeed();
    });
  }

  void _updateMockLocation() {
    if (_currentLocation == null) return;

    double lat = _currentLocation!.latitude!;
    double lng = _currentLocation!.longitude!;

    // Realistic speed updates (like a car on roads)
    double speedKmh = _currentSpeed;
    double speedMs = speedKmh / 3.6;

    // More realistic heading changes (smoother turns)
    double headingRad = _currentHeading * (pi / 180);
    
    // Calculate movement based on current speed and heading
    double deltaLat = (speedMs * cos(headingRad) * 2) / 111000;
    double deltaLng = (speedMs * sin(headingRad) * 2) / (111000 * cos(lat * (pi / 180)));

    // Add slight GPS noise but keep it realistic
    double newLat = lat + deltaLat + (_random.nextDouble() - 0.5) * 0.000005; // Reduced noise
    double newLng = lng + deltaLng + (_random.nextDouble() - 0.5) * 0.000005;

    _currentLocation = LocationData.fromMap({
      'latitude': newLat,
      'longitude': newLng,
      'accuracy': 3.0 + _random.nextDouble() * 2,
      'altitude': 400.0 + _random.nextDouble() * 10, // Less altitude variation
      'speed': _currentSpeed / 3.6, // Convert km/h to m/s for accurate GPS data
      'speedAccuracy': 0.5 + _random.nextDouble() * 0.5,
      'heading': _currentHeading,
      'time': DateTime.now().millisecondsSinceEpoch.toDouble(),
    });

    _locationController.add(_currentLocation!);
  }

  void _updateMockHeading() {
    // Smoother heading changes (like real driving)
    double variation = (_random.nextDouble() - 0.5) * 3; // Reduced variation for smoother turns
    _currentHeading = (_currentHeading + variation) % 360;
    if (_currentHeading < 0) _currentHeading += 360;
    
    _headingController.add(_currentHeading);
  }

  void _updateMockSpeed() {
    // More realistic speed patterns for road driving
    if (_random.nextDouble() < 0.4) {
      double variation = (_random.nextDouble() - 0.5) * 8; // Smaller speed variations
      _currentSpeed = ((_currentSpeed + variation).clamp(0, 120)).toDouble();
      
      // Keep speeds in realistic ranges most of the time
      if (_currentSpeed < 20 && _random.nextDouble() < 0.7) {
        _currentSpeed = 30 + _random.nextDouble() * 50; // City driving speeds
      } else if (_currentSpeed > 100 && _random.nextDouble() < 0.8) {
        _currentSpeed = 60 + _random.nextDouble() * 30; // Highway speeds
      }
    }
    
    // Simulate traffic patterns
    if (_random.nextDouble() < 0.1) {
      // Occasional traffic jam
      _currentSpeed = _currentSpeed * 0.3;
    } else if (_random.nextDouble() < 0.05) {
      // Occasional acceleration (like overtaking)
      _currentSpeed = (_currentSpeed * 1.3).clamp(0, 120);
    }
  }

  void simulateMovement({double? targetSpeed, double? targetHeading}) {
    if (targetSpeed != null) {
      _currentSpeed = targetSpeed;
    }
    if (targetHeading != null) {
      _currentHeading = targetHeading;
    }
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