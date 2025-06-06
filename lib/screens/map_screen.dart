import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';
import '../models/alert.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import '../services/offline_storage.dart';
import '../services/socket_service.dart';
import '../services/connectivity_service.dart';
import '../services/notification_service.dart';
import '../widgets/alert_marker.dart';

class MapScreen extends StatefulWidget {
  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  // Controllers
  final MapController _mapController = MapController();
  
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
  
  @override
  void initState() {
    super.initState();
    _initServices();
  }

  Future<void> _initServices() async {
    try {
      // Initialize notification service
      await _notificationService.initialize();
      
      // Initialize API service
      await _apiService.initialize();
      
      // Initialize location service
      await _locationService.initialize();
      
      // Listen to connectivity status
      _connectivityService.connectionStream.listen((isConnected) {
        setState(() {
          _isOnline = isConnected;
        });
        
        if (isConnected) {
          // Reconnect socket when back online
          _socketService.connect();
          // Sync any unsynced alerts
          _syncOfflineAlerts();
          // Refresh alerts from server
          _fetchNearbyAlerts();
        } else {
          // Load local alerts when offline
          _loadLocalAlerts();
        }
      });
      
      // Listen to location updates
      _locationService.locationStream.listen((LocationData location) {
        setState(() {
          _currentLocation = LatLng(location.latitude!, location.longitude!);
          if (!_isLocationReady) _isLocationReady = true;
        });
        
        // Center map on current location
        try {
  _mapController.move(_currentLocation, _mapController.zoom);
} catch (e) {
  print('Could not move map: $e');
}
        
        // Fetch nearby alerts when online
        if (_isOnline) _fetchNearbyAlerts();
        
        // Check for alerts in driving direction
        _checkAlertsAhead();
      });
      
      // Listen to heading changes
      _locationService.headingStream.listen((heading) {
        // Update any heading-dependent UI or logic
        _checkAlertsAhead();
      });
      
      // Connect socket for real-time updates
      _socketService.connect();
      
      // Listen to socket events
      _socketService.onNewAlert.listen((alert) {
        setState(() {
          // Add new alert if not already in list
          if (!_alerts.any((a) => a.id == alert.id)) {
            _alerts.add(alert);
          }
        });
      });
      
      _socketService.onAlertConfirmed.listen((data) {
        setState(() {
          // Update confirmed count
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
          // Remove dismissed alert
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
      // Continue with offline mode
      setState(() {
        _isOnline = false;
      });
      
      // Load local alerts if online initialization fails
      await _loadLocalAlerts();
    }
  }

  Future<void> _fetchNearbyAlerts() async {
    if (!_isLocationReady) return;
    
    try {
      final alerts = await _apiService.getNearbyAlerts(
        _currentLocation.latitude,
        _currentLocation.longitude,
        radius: 10000, // 10km radius
      );
      
      setState(() {
        _alerts = alerts;
      });
    } catch (e) {
      print('Error fetching alerts: $e');
      setState(() {
        _isOnline = false;
      });
      
      // Load local alerts if fetching fails
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
  
  void _checkAlertsAhead() async {
    if (!_isLocationReady) return;
    
    try {
      if (_isOnline) {
        // Get alerts in driving direction
        final directionalAlerts = await _apiService.getDirectionalAlerts(
          _currentLocation.latitude,
          _currentLocation.longitude,
          _locationService.currentHeading,
          radius: 2000,  // 2km ahead
          angle: 60,     // 60 degree field of view
        );
        
        // Show notification for close alerts
        for (var alert in directionalAlerts) {
          if (alert.distance != null && alert.distance! < 500) {
            // Only alert for alerts within 500m
            _notificationService.showAlertNotification(alert);
          }
        }
      } else {
        // Use local alerts when offline
        final localAlerts = await _offlineStorage.getLocalAlerts();
        
        // Calculate which alerts are ahead based on heading
        // This is a simplified version and would need more complex
        // calculation for accurate results
        for (var alert in localAlerts) {
          // Calculate bearing to alert
          final bearing = _calculateBearing(
            _currentLocation.latitude,
            _currentLocation.longitude,
            alert.latitude,
            alert.longitude,
          );
          
          // Calculate distance to alert
          final distance = _calculateDistance(
            _currentLocation.latitude,
            _currentLocation.longitude,
            alert.latitude,
            alert.longitude,
          );
          
          // Check if alert is ahead in driving direction (within 30 degrees)
          final headingDiff = (bearing - _locationService.currentHeading).abs() % 360;
          if ((headingDiff <= 30 || headingDiff >= 330) && distance < 500) {
            // Create a copy with distance information
            final alertWithDistance = Alert(
              id: alert.id,
              type: alert.type,
              latitude: alert.latitude,
              longitude: alert.longitude,
              reportedAt: alert.reportedAt,
              confirmedCount: alert.confirmedCount,
              isActive: alert.isActive,
              distance: distance,
            );
            
            _notificationService.showAlertNotification(alertWithDistance);
          }
        }
      }
    } catch (e) {
      print('Error checking alerts ahead: $e');
    }
  }
  
  // Calculate bearing between two points
  double _calculateBearing(double lat1, double lon1, double lat2, double lon2) {
    final double dLon = _toRadians(lon2 - lon1);
    final double lat1Rad = _toRadians(lat1);
    final double lat2Rad = _toRadians(lat2);
    
    final double y = math.sin(dLon) * math.cos(lat2Rad);
    final double x = math.cos(lat1Rad) * math.sin(lat2Rad) -
                     math.sin(lat1Rad) * math.cos(lat2Rad) * math.cos(dLon);
    final double bearing = math.atan2(y, x);
    
    return (bearing * 180.0 / math.pi + 360) % 360;
  }
  
  double _toRadians(double degrees) {
    return degrees * (math.pi / 180.0);
  }
  
  // Calculate distance between two points in meters
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double p = 0.017453292519943295; // math.PI / 180
    final double a = 0.5 - 
      math.cos((lat2 - lat1) * p) / 2 + 
      math.cos(lat1 * p) * math.cos(lat2 * p) * (1 - math.cos((lon2 - lon1) * p)) / 2;
    return 12742 * math.asin(math.sqrt(a)) * 1000; // 2 * R * asin(sqrt(a)) * 1000 for meters
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
        // Save locally if online reporting fails
        await _offlineStorage.saveAlert(alert);
        setState(() {
          _isOnline = false;
          _alerts.add(alert);
        });
      }
    } else {
      // Save locally if offline
      await _offlineStorage.saveAlert(alert);
      setState(() {
        _alerts.add(alert);
      });
    }
  }

  void _confirmAlert(Alert alert) async {
    if (_isOnline && alert.id != null) {
      try {
        final success = await _apiService.confirmAlert(alert.id!);
        if (success) {
          // Update alerts list
          await _fetchNearbyAlerts();
        }
      } catch (e) {
        print('Error confirming alert: $e');
      }
    }
  }

  void _dismissAlert(Alert alert) async {
    if (_isOnline && alert.id != null) {
      try {
        final success = await _apiService.dismissAlert(alert.id!);
        if (success) {
          // Update alerts list
          await _fetchNearbyAlerts();
        }
      } catch (e) {
        print('Error dismissing alert: $e');
      }
    }
  }

  void _showAddAlertDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Report Alert'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.car_crash, color: Colors.red),
                title: Text('Accident'),
                onTap: () {
                  Navigator.pop(context);
                  _addAlert('accident');
                },
              ),
              ListTile(
                leading: Icon(Icons.local_fire_department, color: Colors.orange),
                title: Text('Fire'),
                onTap: () {
                  Navigator.pop(context);
                  _addAlert('fire');
                },
              ),
              ListTile(
                leading: Icon(Icons.local_police, color: Colors.blue),
                title: Text('Police'),
                onTap: () {
                  Navigator.pop(context);
                  _addAlert('police');
                },
              ),
              ListTile(
                leading: Icon(Icons.block, color: Colors.black),
                title: Text('Blocked Road'),
                onTap: () {
                  Navigator.pop(context);
                  _addAlert('blocked_road');
                },
              ),
              ListTile(
                leading: Icon(Icons.traffic, color: Colors.yellow.shade700),
                title: Text('Traffic'),
                onTap: () {
                  Navigator.pop(context);
                  _addAlert('traffic');
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLocationReady
          ? Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    center: _currentLocation,
                    zoom: 15.0,
                    interactiveFlags: InteractiveFlag.all,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: _isOnline
                          ? 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'
                          : 'http://y192.168.0.50:3000/osm_tiles/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.traffic_alert_app',
                    ),
                    MarkerLayer(
                      markers: [
                        // Current location marker
                        Marker(
                          point: _currentLocation,
                          width: 40,
                          height: 40,
                          builder: (context) => Container(
                            child: Icon(
                              Icons.my_location,
                              color: Colors.blue,
                              size: 30,
                            ),
                          ),
                        ),
                        // Alert markers
                        ..._alerts.map((alert) {
                          return Marker(
                            point: alert.location,
                            width: 40,
                            height: 40,
                            builder: (context) => GestureDetector(
                              onTap: () => _showAlertDialog(alert),
                              child: AlertMarker(alert: alert),
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                  ],
                ),
                // Add Alert Button
                Positioned(
                  right: 16,
                  bottom: 100,
                  child: FloatingActionButton(
                    onPressed: _showAddAlertDialog,
                    child: Icon(Icons.add),
                    tooltip: 'Report Alert',
                  ),
                ),
                // Online/Offline indicator
                Positioned(
                  top: 50,
                  right: 16,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _isOnline ? Colors.green : Colors.red,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _isOnline ? 'Online' : 'Offline',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            )
          : Center(child: CircularProgressIndicator()),
    );
  }

  void _showAlertDialog(Alert alert) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(_getAlertTitle(alert.type)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Reported: ${_formatDateTime(alert.reportedAt)}'),
              Text('Confirmed by: ${alert.confirmedCount} users'),
              SizedBox(height: 16),
              Text('Is this alert still active?'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _dismissAlert(alert);
              },
              child: Text('No, it\'s gone'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _confirmAlert(alert);
              },
              child: Text('Yes, still there'),
            ),
          ],
        );
      },
    );
  }
  
  String _getAlertTitle(String type) {
    switch (type) {
      case 'accident': return 'Accident';
      case 'fire': return 'Fire';
      case 'police': return 'Police';
      case 'blocked_road': return 'Blocked Road';
      case 'traffic': return 'Traffic';
      default: return 'Alert';
    }
  }
  
  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minutes ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hours ago';
    } else {
      return '${difference.inDays} days ago';
    }
  }
  
  @override
  void dispose() {
    _locationService.dispose();
    _socketService.dispose();
    _connectivityService.dispose();
    super.dispose();
  }
}