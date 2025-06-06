import 'package:flutter/material.dart';
import '../models/alert.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import '../services/offline_storage.dart';
import '../services/socket_service.dart';
import '../services/connectivity_service.dart';
import '../services/notification_service.dart';
import 'package:location/location.dart';
import 'package:latlong2/latlong.dart';
import 'meter_view.dart';
import 'map_view_new.dart';
import '../widgets/report_modal.dart';

class RadarAlertScreen extends StatefulWidget {
  @override
  _RadarAlertScreenState createState() => _RadarAlertScreenState();
}

class _RadarAlertScreenState extends State<RadarAlertScreen> {
  // View state
  String _currentView = 'meter'; // 'meter' or 'map'
  bool _showReportModal = false;
  
  // Services
  final LocationService _locationService = LocationService();
  final ApiService _apiService = ApiService(baseUrl: 'http://192.168.0.50:3000');
  final OfflineStorage _offlineStorage = OfflineStorage();
  final SocketService _socketService = SocketService(serverUrl: 'http://192.168.0.50:3000');
  final ConnectivityService _connectivityService = ConnectivityService();
  final NotificationService _notificationService = NotificationService();
  
  // State variables
  List<Alert> _alerts = [];
  LatLng _currentLocation = LatLng(0, 0);
  bool _isLocationReady = false;
  bool _isOnline = true;
  double _currentSpeed = 0;
  Set<int> _confirmedReports = <int>{};

  @override
  void initState() {
    super.initState();
    _initServices();
  }

  Future<void> _initServices() async {
    try {
      // Initialize services
      await _notificationService.initialize();
      await _apiService.initialize();
      await _locationService.initialize();
      
      // Listen to connectivity status
      _connectivityService.connectionStream.listen((isConnected) {
        setState(() {
          _isOnline = isConnected;
        });
        
        if (isConnected) {
          _socketService.connect();
          _syncOfflineAlerts();
          _fetchNearbyAlerts();
        } else {
          _loadLocalAlerts();
        }
      });
      
      // Listen to location updates
      _locationService.locationStream.listen((LocationData location) {
        setState(() {
          _currentLocation = LatLng(location.latitude!, location.longitude!);
          _currentSpeed = location.speed ?? 0;
          if (!_isLocationReady) _isLocationReady = true;
        });
        
        if (_isOnline) _fetchNearbyAlerts();
      });
      
      // Connect socket for real-time updates
      _socketService.connect();
      
      // Socket event listeners
      _socketService.onNewAlert.listen((alert) {
        setState(() {
          if (!_alerts.any((a) => a.id == alert.id)) {
            _alerts.add(alert);
          }
        });
      });
      
      _socketService.onAlertConfirmed.listen((data) {
        setState(() {
          final index = _alerts.indexWhere((a) => a.id == data['id']);
          if (index != -1) {
            final updatedAlert = Alert(
              id: _alerts[index].id,
              type: _alerts[index].type,
              latitude: _alerts[index].latitude,
              longitude: _alerts[index].longitude,
              reportedAt: _alerts[index].reportedAt,
              confirmedCount: data['confirmedCount'],
              isActive: _alerts[index].isActive,
            );
            _alerts[index] = updatedAlert;
          }
        });
      });
      
      _socketService.onAlertDismissed.listen((alertId) {
        setState(() {
          _alerts.removeWhere((a) => a.id == alertId);
        });
      });
      
      // Initial data loading
      if (await _connectivityService.checkConnection()) {
        _fetchNearbyAlerts();
      } else {
        _loadLocalAlerts();
      }
    } catch (e) {
      print('Error initializing services: $e');
      setState(() {
        _isOnline = false;
      });
      await _loadLocalAlerts();
    }
  }

  Future<void> _fetchNearbyAlerts() async {
    if (!_isLocationReady) return;
    
    try {
      final alerts = await _apiService.getNearbyAlerts(
        _currentLocation.latitude,
        _currentLocation.longitude,
        radius: 10000,
      );
      
      setState(() {
        _alerts = alerts;
      });
    } catch (e) {
      print('Error fetching alerts: $e');
      setState(() {
        _isOnline = false;
      });
      await _loadLocalAlerts();
    }
  }

  Future<void> _loadLocalAlerts() async {
    try {
      final localAlerts = await _offlineStorage.getLocalAlerts();
      setState(() {
        _alerts = localAlerts;
      });
    } catch (e) {
      print('Error loading local alerts: $e');
    }
  }

  Future<void> _syncOfflineAlerts() async {
    if (!_isOnline) return;
    
    try {
      final unsyncedAlerts = await _offlineStorage.getUnsyncedAlerts();
      
      for (var alertMap in unsyncedAlerts) {
        final result = await _apiService.reportAlert(
          alertMap['type'],
          alertMap['latitude'],
          alertMap['longitude'],
        );
        
        if (result != null) {
          await _offlineStorage.markAsSynced(alertMap['id'], result.id!);
        }
      }
    } catch (e) {
      print('Error syncing offline alerts: $e');
    }
  }

  void _confirmAlert(Alert alert) async {
    if (_isOnline && alert.id != null) {
      try {
        final success = await _apiService.confirmAlert(alert.id!);
        if (success) {
          setState(() {
            _confirmedReports.add(alert.id!);
          });
          await _fetchNearbyAlerts();
        }
      } catch (e) {
        print('Error confirming alert: $e');
      }
    } else {
      // For offline mode, just mark as confirmed locally
      setState(() {
        if (alert.id != null) {
          _confirmedReports.add(alert.id!);
        }
      });
    }
  }

  Future<void> _addAlert(String type) async {
    if (!_isLocationReady) return;
    
    final alert = Alert(
      type: type,
      latitude: _currentLocation.latitude,
      longitude: _currentLocation.longitude,
      reportedAt: DateTime.now(),
    );
    
    if (_isOnline) {
      try {
        final result = await _apiService.reportAlert(
          type,
          _currentLocation.latitude,
          _currentLocation.longitude,
        );
        
        if (result != null) {
          setState(() {
            _alerts.add(result);
          });
        }
      } catch (e) {
        print('Error reporting alert: $e');
        await _offlineStorage.saveAlert(alert);
        setState(() {
          _isOnline = false;
          _alerts.add(alert);
        });
      }
    } else {
      await _offlineStorage.saveAlert(alert);
      setState(() {
        _alerts.add(alert);
      });
    }
  }

  Alert? get _nextAlert {
    if (_alerts.isEmpty) return null;
    return _alerts.first;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111827), // gray-900
      body: _showReportModal
          ? Stack(
              children: [
                // Main content
                SafeArea(
                  child: Column(
                    children: [
                      // Header
                      Container(
                        color: const Color(0xFF1F2937), // gray-800
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'RadarAlert',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Row(
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF374151), // gray-700
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: IconButton(
                                    onPressed: () {
                                      setState(() {
                                        _currentView = _currentView == 'map' ? 'meter' : 'map';
                                      });
                                    },
                                    icon: Icon(
                                      _currentView == 'map' ? Icons.speed : Icons.map,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      
                      // Main content
                      Expanded(
                        child: _currentView == 'meter'
                            ? MeterView(
                                currentSpeed: _currentSpeed,
                                nextAlert: _nextAlert,
                                alerts: _alerts,
                                confirmedReports: _confirmedReports,
                                onConfirmAlert: _confirmAlert,
                              )
                            : MapViewNew(
                                currentLocation: _currentLocation,
                                alerts: _alerts,
                                currentSpeed: _currentSpeed,
                                nextAlert: _nextAlert,
                                isLocationReady: _isLocationReady,
                                isOnline: _isOnline,
                              ),
                      ),
                    ],
                  ),
                ),
                
                // Modal overlay
                ReportModal(
                  currentLocation: _currentLocation,
                  onClose: () {
                    setState(() {
                      _showReportModal = false;
                    });
                  },
                  onSubmitReport: (String type) {
                    _addAlert(type);
                    setState(() {
                      _showReportModal = false;
                    });
                  },
                ),
              ],
            )
          : SafeArea(
              child: Column(
                children: [
                  // Header
                  Container(
                    color: const Color(0xFF1F2937), // gray-800
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'RadarAlert',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Row(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF374151), // gray-700
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: IconButton(
                                onPressed: () {
                                  setState(() {
                                    _currentView = _currentView == 'map' ? 'meter' : 'map';
                                  });
                                },
                                icon: Icon(
                                  _currentView == 'map' ? Icons.speed : Icons.map,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  // Main content
                  Expanded(
                    child: _currentView == 'meter'
                        ? MeterView(
                            currentSpeed: _currentSpeed,
                            nextAlert: _nextAlert,
                            alerts: _alerts,
                            confirmedReports: _confirmedReports,
                            onConfirmAlert: _confirmAlert,
                          )
                        : MapViewNew(
                            currentLocation: _currentLocation,
                            alerts: _alerts,
                            currentSpeed: _currentSpeed,
                            nextAlert: _nextAlert,
                            isLocationReady: _isLocationReady,
                            isOnline: _isOnline,
                          ),
                  ),
                ],
              ),
            ),
      
      // Floating action button for reporting
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          setState(() {
            _showReportModal = true;
          });
        },
        backgroundColor: const Color(0xFFDC2626), // red-600
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  @override
  void dispose() {
    _locationService.dispose();
    _socketService.dispose();
    _connectivityService.dispose();
    super.dispose();
  }
}