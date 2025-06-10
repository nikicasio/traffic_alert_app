import 'dart:async';
import 'package:location/location.dart';
import 'speed_limit_service.dart';

class DeviceLocationService {
  static final DeviceLocationService _instance = DeviceLocationService._internal();
  factory DeviceLocationService() => _instance;
  DeviceLocationService._internal();

  StreamController<LocationData> _locationController = StreamController<LocationData>.broadcast();
  StreamController<double> _headingController = StreamController<double>.broadcast();
  StreamController<SpeedLimitResult?> _speedLimitController = StreamController<SpeedLimitResult?>.broadcast();
  
  Stream<LocationData> get locationStream => _locationController.stream;
  Stream<double> get headingStream => _headingController.stream;
  Stream<SpeedLimitResult?> get speedLimitStream => _speedLimitController.stream;

  LocationData? _currentLocation;
  double _currentHeading = 0.0;
  SpeedLimitResult? _currentSpeedLimit;
  
  Location _location = Location();
  StreamSubscription<LocationData>? _locationSubscription;
  final SpeedLimitService _speedLimitService = SpeedLimitService();
  Timer? _speedLimitTimer;
  
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  LocationData? get currentLocation => _currentLocation;
  double get currentHeading => _currentHeading;
  SpeedLimitResult? get currentSpeedLimit => _currentSpeedLimit;

  Future<void> initialize() async {
    if (_isInitialized) return;

    // If controllers are closed, recreate them
    if (_locationController.isClosed) {
      _locationController = StreamController<LocationData>.broadcast();
    }
    if (_headingController.isClosed) {
      _headingController = StreamController<double>.broadcast();
    }
    if (_speedLimitController.isClosed) {
      _speedLimitController = StreamController<SpeedLimitResult?>.broadcast();
    }

    try {
      // Check if location service is enabled
      bool serviceEnabled = await _location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await _location.requestService();
        if (!serviceEnabled) {
          throw Exception('Location service is disabled');
        }
      }

      // Check for location permissions
      PermissionStatus permissionGranted = await _location.hasPermission();
      if (permissionGranted == PermissionStatus.denied) {
        permissionGranted = await _location.requestPermission();
        if (permissionGranted != PermissionStatus.granted) {
          throw Exception('Location permission denied');
        }
      }

      // Configure location settings for high accuracy
      await _location.changeSettings(
        accuracy: LocationAccuracy.high,
        interval: 5000, // Update every 5 seconds
        distanceFilter: 10, // Update when moved 10 meters
      );

      // Get initial location
      _currentLocation = await _location.getLocation();
      _currentHeading = _currentLocation?.heading ?? 0.0;
      
      _isInitialized = true;
      _locationController.add(_currentLocation!);
      _headingController.add(_currentHeading);

      // Start listening to location updates
      _startLocationUpdates();
      
      // Start speed limit updates
      _startSpeedLimitUpdates();
      
      print('Device location service initialized successfully');
    } catch (e) {
      print('Error initializing device location service: $e');
      // Don't throw error to prevent app crash
      _isInitialized = false;
    }
  }

  void _startLocationUpdates() {
    _locationSubscription?.cancel(); // Cancel existing subscription
    
    _locationSubscription = _location.onLocationChanged.listen(
      (LocationData locationData) {
        _currentLocation = locationData;
        _currentHeading = locationData.heading ?? _currentHeading;
        
        // Only add to controllers if they're not closed
        if (!_locationController.isClosed) {
          _locationController.add(_currentLocation!);
        }
        if (!_headingController.isClosed) {
          _headingController.add(_currentHeading);
        }
        
        print('Location updated: ${locationData.latitude}, ${locationData.longitude}, ${(locationData.speed ?? 0) * 3.6} km/h');
        
        // Trigger speed limit update when location changes significantly
        _updateSpeedLimitIfNeeded();
      },
      onError: (error) {
        print('Location stream error: $error');
      },
    );
  }

  void _startSpeedLimitUpdates() {
    // Update speed limit every 30 seconds or when location changes significantly
    _speedLimitTimer?.cancel();
    _speedLimitTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _updateSpeedLimitIfNeeded();
    });
    
    // Get initial speed limit
    _updateSpeedLimitIfNeeded();
  }

  void _updateSpeedLimitIfNeeded() async {
    if (_currentLocation == null) return;
    
    try {
      final speedLimit = await _speedLimitService.getSpeedLimit(
        _currentLocation!.latitude!,
        _currentLocation!.longitude!,
      );
      
      if (speedLimit != null) {
        _currentSpeedLimit = speedLimit;
        
        // Only add to controller if it's not closed
        if (!_speedLimitController.isClosed) {
          _speedLimitController.add(speedLimit);
        }
        
        print('Speed limit updated: ${speedLimit.speedLimitKmh} km/h on ${speedLimit.roadType}');
      }
    } catch (e) {
      print('Error updating speed limit: $e');
    }
  }

  Future<LocationData> getLocation() async {
    if (!_isInitialized) await initialize();
    return _currentLocation!;
  }

  void dispose() {
    _locationSubscription?.cancel();
    _locationSubscription = null;
    
    _speedLimitTimer?.cancel();
    _speedLimitTimer = null;
    
    if (!_locationController.isClosed) {
      _locationController.close();
    }
    if (!_headingController.isClosed) {
      _headingController.close();
    }
    if (!_speedLimitController.isClosed) {
      _speedLimitController.close();
    }
    
    _isInitialized = false;
  }
}