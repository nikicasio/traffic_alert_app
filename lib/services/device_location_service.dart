import 'dart:async';
import 'package:location/location.dart';

class DeviceLocationService {
  static final DeviceLocationService _instance = DeviceLocationService._internal();
  factory DeviceLocationService() => _instance;
  DeviceLocationService._internal();

  final _locationController = StreamController<LocationData>.broadcast();
  final _headingController = StreamController<double>.broadcast();
  
  Stream<LocationData> get locationStream => _locationController.stream;
  Stream<double> get headingStream => _headingController.stream;

  LocationData? _currentLocation;
  double _currentHeading = 0.0;
  
  Location _location = Location();
  StreamSubscription<LocationData>? _locationSubscription;
  
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  LocationData? get currentLocation => _currentLocation;
  double get currentHeading => _currentHeading;

  Future<void> initialize() async {
    if (_isInitialized) return;

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
        interval: 2000, // Update every 2 seconds
        distanceFilter: 2, // Update when moved 2 meters
      );

      // Get initial location
      _currentLocation = await _location.getLocation();
      _currentHeading = _currentLocation?.heading ?? 0.0;
      
      _isInitialized = true;
      _locationController.add(_currentLocation!);
      _headingController.add(_currentHeading);

      // Start listening to location updates
      _startLocationUpdates();
      
      print('Device location service initialized successfully');
    } catch (e) {
      print('Error initializing device location service: $e');
      throw e;
    }
  }

  void _startLocationUpdates() {
    _locationSubscription = _location.onLocationChanged.listen(
      (LocationData locationData) {
        _currentLocation = locationData;
        _currentHeading = locationData.heading ?? _currentHeading;
        
        _locationController.add(_currentLocation!);
        _headingController.add(_currentHeading);
        
        print('Location updated: ${locationData.latitude}, ${locationData.longitude}, ${(locationData.speed ?? 0) * 3.6} km/h');
      },
      onError: (error) {
        print('Location stream error: $error');
      },
    );
  }

  Future<LocationData> getLocation() async {
    if (!_isInitialized) await initialize();
    return _currentLocation!;
  }

  void dispose() {
    _locationSubscription?.cancel();
    _locationController.close();
    _headingController.close();
    _isInitialized = false;
  }
}