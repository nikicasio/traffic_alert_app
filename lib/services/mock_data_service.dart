import 'dart:async';
import 'dart:math';
import '../models/alert.dart';
import 'package:latlong2/latlong.dart';

class MockDataService {
  static final MockDataService _instance = MockDataService._internal();
  factory MockDataService() => _instance;
  MockDataService._internal();

  final _alertsController = StreamController<List<Alert>>.broadcast();
  final _newAlertController = StreamController<Alert>.broadcast();
  final _alertConfirmedController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<List<Alert>> get alertsStream => _alertsController.stream;
  Stream<Alert> get newAlertStream => _newAlertController.stream;
  Stream<Map<String, dynamic>> get alertConfirmedStream => _alertConfirmedController.stream;

  List<Alert> _alerts = [];
  Set<int> _passedAlerts = <int>{}; // Track alerts user has passed (for confirmation prompt)
  Map<int, int> _notThereReports = <int, int>{}; // Track "not there" reports per alert
  int _nextId = 1;
  final Random _random = Random();

  List<Alert> get alerts => List.unmodifiable(_alerts);

  void initialize() {
    _generateMockAlerts();
    _startRandomUpdates();
  }

  void _generateMockAlerts() {
    // Generate sample alerts in various locations for testing
    // These will be positioned globally so you can test wherever you are
    final mockAlerts = [
      Alert(
        id: _nextId++,
        type: 'police',
        latitude: 37.7749 + (_random.nextDouble() - 0.5) * 0.01, // San Francisco area
        longitude: -122.4194 + (_random.nextDouble() - 0.5) * 0.01,
        reportedAt: DateTime.now().subtract(Duration(minutes: _random.nextInt(30))),
        confirmedCount: 5 + _random.nextInt(20),
        isActive: true,
      ),
      Alert(
        id: _nextId++,
        type: 'roadwork',
        latitude: 40.7128 + (_random.nextDouble() - 0.5) * 0.01, // New York area
        longitude: -74.0060 + (_random.nextDouble() - 0.5) * 0.01,
        reportedAt: DateTime.now().subtract(Duration(minutes: _random.nextInt(60))),
        confirmedCount: 12 + _random.nextInt(30),
        isActive: true,
      ),
      Alert(
        id: _nextId++,
        type: 'obstacle',
        latitude: 51.5074 + (_random.nextDouble() - 0.5) * 0.01, // London area
        longitude: -0.1278 + (_random.nextDouble() - 0.5) * 0.01,
        reportedAt: DateTime.now().subtract(Duration(minutes: _random.nextInt(15))),
        confirmedCount: 3 + _random.nextInt(10),
        isActive: true,
      ),
      Alert(
        id: _nextId++,
        type: 'traffic',
        latitude: 48.8566 + (_random.nextDouble() - 0.5) * 0.01, // Paris area
        longitude: 2.3522 + (_random.nextDouble() - 0.5) * 0.01,
        reportedAt: DateTime.now().subtract(Duration(minutes: _random.nextInt(45))),
        confirmedCount: 8 + _random.nextInt(15),
        isActive: true,
      ),
    ];

    _alerts = mockAlerts;
    _alertsController.add(_alerts);
  }

  void _startRandomUpdates() {
    Timer.periodic(Duration(minutes: 2), (timer) {
      if (_random.nextBool()) {
        _addRandomAlert();
      }
    });

    Timer.periodic(Duration(seconds: 30), (timer) {
      if (_alerts.isNotEmpty && _random.nextDouble() < 0.1) {
        _confirmRandomAlert();
      }
    });
  }

  void _addRandomAlert() {
    final types = ['police', 'roadwork', 'obstacle', 'traffic'];
    final type = types[_random.nextInt(types.length)];
    
    // Generate random alert along the GPX route area (Aachen, Germany)
    final baseLatitudes = [50.7440, 50.7500, 50.7560, 50.7620, 50.7680, 50.7740];
    final baseLongitudes = [6.1720, 6.1650, 6.1580, 6.1510, 6.1440, 6.1370];
    
    final baseLat = baseLatitudes[_random.nextInt(baseLatitudes.length)];
    final baseLng = baseLongitudes[_random.nextInt(baseLongitudes.length)];
    
    final alert = Alert(
      id: _nextId++,
      type: type,
      latitude: baseLat + (_random.nextDouble() - 0.5) * 0.002, // Small variation
      longitude: baseLng + (_random.nextDouble() - 0.5) * 0.002,
      reportedAt: DateTime.now(),
      confirmedCount: 1,
      isActive: true,
    );

    _alerts.add(alert);
    _alertsController.add(_alerts);
    _newAlertController.add(alert);
  }

  void _confirmRandomAlert() {
    if (_alerts.isEmpty) return;
    
    final alert = _alerts[_random.nextInt(_alerts.length)];
    final index = _alerts.indexWhere((a) => a.id == alert.id);
    
    if (index != -1) {
      final updatedAlert = Alert(
        id: alert.id,
        type: alert.type,
        latitude: alert.latitude,
        longitude: alert.longitude,
        reportedAt: alert.reportedAt,
        confirmedCount: alert.confirmedCount + 1,
        isActive: alert.isActive,
      );
      
      _alerts[index] = updatedAlert;
      _alertsController.add(_alerts);
      _alertConfirmedController.add({
        'id': alert.id,
        'confirmedCount': updatedAlert.confirmedCount,
      });
    }
  }

  List<Alert> getNearbyAlerts(double lat, double lng, {double radius = 10000}) {
    final Distance distance = Distance();
    
    // Check for alerts user has passed (for confirmation prompt)
    _checkForPassedAlerts(lat, lng);
    
    // Filter alerts based on visibility distance (always show active alerts)
    final visibleAlerts = _alerts.where((alert) {
      final alertDistance = distance.as(LengthUnit.Meter,
          LatLng(lat, lng), LatLng(alert.latitude, alert.longitude));
      
      // Show all alerts within 1000m range (don't hide passed alerts)
      bool isWithinRange = alertDistance <= radius && alert.isActive;
      bool isVisible = alertDistance <= 1000; // Show only within 1km
      
      return isWithinRange && isVisible;
    }).toList()
      ..sort((a, b) {
        final distanceA = distance.as(LengthUnit.Meter,
            LatLng(lat, lng), LatLng(a.latitude, a.longitude));
        final distanceB = distance.as(LengthUnit.Meter,
            LatLng(lat, lng), LatLng(b.latitude, b.longitude));
        return distanceA.compareTo(distanceB);
      });
    
    return visibleAlerts;
  }
  
  void _checkForPassedAlerts(double lat, double lng) {
    final Distance distance = Distance();
    
    for (var alert in _alerts) {
      // Skip if already marked as passed
      if (_passedAlerts.contains(alert.id)) continue;
      
      final alertDistance = distance.as(LengthUnit.Meter,
          LatLng(lat, lng), LatLng(alert.latitude, alert.longitude));
      
      // Mark as passed if user is very close (5m threshold) - but keep alert visible
      if (alertDistance <= 5) {
        _passedAlerts.add(alert.id!);
        print('Alert passed by user: ${alert.type} at ${alertDistance.round()}m - showing confirmation prompt');
        
        // Notify UI to show confirmation prompt
        _alertsController.add(_alerts);
      }
    }
  }

  // Get alerts that user has passed (for confirmation prompt)
  Set<int> get passedAlerts => Set.unmodifiable(_passedAlerts);

  // Report alert as "not there" 
  Future<bool> reportAlertNotThere(int alertId) async {
    await Future.delayed(Duration(milliseconds: 300));
    
    _notThereReports[alertId] = (_notThereReports[alertId] ?? 0) + 1;
    
    // Remove alert if 5 or more people reported it's not there
    if (_notThereReports[alertId]! >= 5) {
      _alerts.removeWhere((alert) => alert.id == alertId);
      _notThereReports.remove(alertId);
      _passedAlerts.remove(alertId);
      
      print('Alert $alertId removed: 5+ reports of "not there"');
      _alertsController.add(_alerts);
      return true;
    }
    
    return false;
  }

  // Report alert as "still there"
  Future<bool> confirmAlertStillThere(int alertId) async {
    await Future.delayed(Duration(milliseconds: 300));
    
    // Reset "not there" counter when someone confirms it's still there
    _notThereReports[alertId] = 0;
    
    return true;
  }

  double getDistanceToAlert(Alert alert, double lat, double lng) {
    final Distance distance = Distance();
    return distance.as(LengthUnit.Meter,
        LatLng(lat, lng), LatLng(alert.latitude, alert.longitude));
  }

  Future<Alert?> reportAlert(String type, double latitude, double longitude) async {
    await Future.delayed(Duration(milliseconds: 500));
    
    final alert = Alert(
      id: _nextId++,
      type: type,
      latitude: latitude,
      longitude: longitude,
      reportedAt: DateTime.now(),
      confirmedCount: 1,
      isActive: true,
    );

    _alerts.add(alert);
    _alertsController.add(_alerts);
    _newAlertController.add(alert);
    
    return alert;
  }

  Future<bool> confirmAlert(int alertId) async {
    await Future.delayed(Duration(milliseconds: 300));
    
    final index = _alerts.indexWhere((a) => a.id == alertId);
    if (index == -1) return false;
    
    final alert = _alerts[index];
    final updatedAlert = Alert(
      id: alert.id,
      type: alert.type,
      latitude: alert.latitude,
      longitude: alert.longitude,
      reportedAt: alert.reportedAt,
      confirmedCount: alert.confirmedCount + 1,
      isActive: alert.isActive,
    );
    
    _alerts[index] = updatedAlert;
    _alertsController.add(_alerts);
    _alertConfirmedController.add({
      'id': alertId,
      'confirmedCount': updatedAlert.confirmedCount,
    });
    
    return true;
  }

  void dispose() {
    _alertsController.close();
    _newAlertController.close();
    _alertConfirmedController.close();
  }
}