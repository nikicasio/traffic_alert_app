import 'dart:math' as math;
import 'dart:async';
import 'package:location/location.dart';
import 'package:flutter_compass/flutter_compass.dart';

class LocationService {
  final Location _location = Location();
  LocationData? _currentLocation;
  double _currentHeading = 0.0;
  
  // Controllers for location and heading streams
  final _locationController = StreamController<LocationData>.broadcast();
  final _headingController = StreamController<double>.broadcast();
  
  // Timers for battery-efficient polling
  Timer? _locationTimer;
  Timer? _headingTimer;
  
  // Movement thresholds
  static const int _fastUpdateInterval = 5; // seconds
  static const int _slowUpdateInterval = 30; // seconds
  static const double _movementThreshold = 5.0; // meters
  
  // Public streams
  Stream<LocationData> get locationStream => _locationController.stream;
  Stream<double> get headingStream => _headingController.stream;
  
  // Current values
  LocationData? get currentLocation => _currentLocation;
  double get currentHeading => _currentHeading;
  
  Future<void> initialize() async {
    bool serviceEnabled;
    PermissionStatus permissionGranted;

    // Check if location service is enabled
    serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _location.requestService();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled');
      }
    }

    // Check if permission is granted
    permissionGranted = await _location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await _location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) {
        throw Exception('Location permission not granted');
      }
    }

    // Configure location settings
    await _location.changeSettings(
      accuracy: LocationAccuracy.high,
      interval: _fastUpdateInterval * 1000,
      distanceFilter: _movementThreshold,
    );

    // Get initial location
    _currentLocation = await _location.getLocation();
    _locationController.add(_currentLocation!);

    // Start intelligent location polling
    _startLocationUpdates();
    
    // Start compass heading updates if available
    if (FlutterCompass.events != null) {
      FlutterCompass.events!.listen((CompassEvent event) {
        if (event.heading != null) {
          _currentHeading = event.heading!;
          _headingController.add(_currentHeading);
        }
      });
    }
  }

  // Intelligent polling for battery efficiency
  void _startLocationUpdates() {
    // Initial location stream setup
    _location.onLocationChanged.listen((LocationData locationData) {
      _currentLocation = locationData;
      _locationController.add(locationData);
    });
    
    // Variable polling rate based on movement
    _locationTimer = Timer.periodic(Duration(seconds: _fastUpdateInterval), (_) async {
      final newLocation = await _location.getLocation();
      
      if (_currentLocation != null) {
        // Calculate distance moved
        final double distanceMoved = _calculateDistance(
          _currentLocation!.latitude!, 
          _currentLocation!.longitude!,
          newLocation.latitude!, 
          newLocation.longitude!
        );
        
        // If moving significantly, keep fast updates
        // Otherwise, slow down to save battery
        if (distanceMoved > _movementThreshold) {
          await _location.changeSettings(
            interval: _fastUpdateInterval * 1000,
            distanceFilter: _movementThreshold,
          );
        } else {
          await _location.changeSettings(
            interval: _slowUpdateInterval * 1000,
            distanceFilter: _movementThreshold * 3,
          );
        }
      }
    });
  }
  
  // Calculate distance between two points in meters
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double p = 0.017453292519943295; // math.PI / 180
    final double a = 0.5 - 
      math.cos((lat2 - lat1) * p) / 2 + 
      math.cos(lat1 * p) * math.cos(lat2 * p) * (1 - math.cos((lon2 - lon1) * p)) / 2;
    return 12742 * math.asin(math.sqrt(a)) * 1000; // 2 * R * asin(sqrt(a)) * 1000 for meters
  }

  void dispose() {
    _locationController.close();
    _headingController.close();
    _locationTimer?.cancel();
    _headingTimer?.cancel();
  }
}