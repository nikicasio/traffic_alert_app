import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/alert.dart';
import '../services/real_api_service.dart';
import '../services/websocket_service.dart';
import '../services/device_location_service.dart';
import '../services/offline_storage.dart';
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

class _RadarAlertScreenState extends State<RadarAlertScreen> 
    with TickerProviderStateMixin {
  // View state
  String _currentView = 'meter'; // 'meter' or 'map'
  bool _showReportModal = false;
  
  // Services
  final DeviceLocationService _locationService = DeviceLocationService();
  final RealApiService _apiService = RealApiService();
  final WebSocketService _websocketService = WebSocketService();
  final OfflineStorage _offlineStorage = OfflineStorage();
  final ConnectivityService _connectivityService = ConnectivityService();
  final NotificationService _notificationService = NotificationService();
  
  // State variables
  List<Alert> _alerts = [];
  LatLng _currentLocation = LatLng(0, 0);
  bool _isLocationReady = false;
  bool _isOnline = true;
  double _currentSpeed = 0;
  double _currentHeading = 0;
  Set<int> _confirmedReports = <int>{};
  
  // Animation controllers
  late AnimationController _viewTransitionController;
  late AnimationController _modalController;
  late Animation<double> _viewFadeAnimation;
  late Animation<Offset> _viewSlideAnimation;
  late Animation<double> _modalAnimation;

  @override
  void initState() {
    super.initState();
    
    // Initialize animation controllers
    _viewTransitionController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _modalController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    // Initialize animations
    _viewFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _viewTransitionController,
      curve: Curves.easeInOut,
    ));
    
    _viewSlideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _viewTransitionController,
      curve: Curves.easeOutCubic,
    ));
    
    _modalAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _modalController,
      curve: Curves.easeOutBack,
    ));
    
    _viewTransitionController.forward();
    _initServices();
  }

  Future<void> _initServices() async {
    try {
      // Initialize services
      await _notificationService.initialize();
      await _apiService.initialize();
      await _websocketService.initialize();
      await _locationService.initialize();
      
      // Update FCM token on server after authentication
      await _notificationService.updateTokenOnServer();
      
      // Listen to connectivity status
      _connectivityService.connectionStream.listen((isConnected) {
        setState(() {
          _isOnline = isConnected;
        });
        
        if (isConnected) {
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
          _currentHeading = location.heading ?? 0;
          if (!_isLocationReady) _isLocationReady = true;
        });
        
        // Update WebSocket location subscriptions
        _websocketService.subscribeToLocationUpdates(
          location.latitude!,
          location.longitude!,
          radiusKm: 10,
        );
        _websocketService.updateUserLocation(location.latitude!, location.longitude!);
        
        _fetchNearbyAlerts();
      });
      
      // Check API health
      final isHealthy = await _apiService.checkHealth();
      print('API Health: $isHealthy');
      
      // Setup WebSocket event listeners
      _setupWebSocketListeners();
      
      // Initial data loading
      setState(() {
        _isOnline = true;
      });
      _fetchNearbyAlerts();
    } catch (e) {
      print('Error initializing services: $e');
      setState(() {
        _isOnline = false;
      });
      await _loadLocalAlerts();
    }
  }

  void _setupWebSocketListeners() {
    // Listen to real-time alert creation
    _websocketService.alertCreatedStream.listen((Alert newAlert) {
      setState(() {
        // Add new alert if not already in the list
        if (!_alerts.any((alert) => alert.id == newAlert.id)) {
          _alerts.add(newAlert);
        }
      });
      
      // Calculate distance and show local notification for real-time alerts
      final alertWithDistance = _calculateAlertDistance(newAlert);
      _notificationService.showAlertNotification(alertWithDistance);
      
      print('New alert received via WebSocket: ${newAlert.type}');
    });

    // Listen to alert confirmations
    _websocketService.alertConfirmedStream.listen((Map<String, dynamic> data) {
      final alertId = data['alert_id'];
      if (alertId != null) {
        setState(() {
          // Update confirmation count for the alert
          final alertIndex = _alerts.indexWhere((alert) => alert.id.toString() == alertId.toString());
          if (alertIndex != -1) {
            // Refresh alerts to get updated confirmation count
            _fetchNearbyAlerts();
          }
        });
        print('Alert confirmed via WebSocket: $alertId');
      }
    });

    // Listen to alert dismissals/expirations
    _websocketService.alertDismissedStream.listen((Map<String, dynamic> data) {
      final alertId = data['alert_id'];
      final shouldRemove = data['should_remove'] ?? false;
      
      if (alertId != null && shouldRemove) {
        setState(() {
          _alerts.removeWhere((alert) => alert.id.toString() == alertId.toString());
        });
        print('Alert removed via WebSocket: $alertId');
      }
    });

    // Listen to WebSocket connection status
    _websocketService.connectionStatusStream.listen((bool isConnected) {
      print('WebSocket connection status: $isConnected');
      if (isConnected && _isLocationReady) {
        // Subscribe to location updates when connection is restored
        _websocketService.subscribeToLocationUpdates(
          _currentLocation.latitude,
          _currentLocation.longitude,
          radiusKm: 10,
        );
      }
    });
  }

  Future<void> _fetchNearbyAlerts() async {
    if (!_isLocationReady) return;
    
    try {
      final alerts = await _apiService.getNearbyAlerts(
        latitude: _currentLocation.latitude,
        longitude: _currentLocation.longitude,
        radius: 10000,
      );
      
      setState(() {
        _alerts = alerts;
        _isOnline = true;
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
          type: alertMap['type'],
          latitude: alertMap['latitude'],
          longitude: alertMap['longitude'],
        );
        
        if (result != null) {
          await _offlineStorage.markAsSynced(alertMap['id'], result.id!);
        }
      }
    } catch (e) {
      print('Error syncing offline alerts: $e');
    }
  }

  void _handleAlertConfirmation(int alertId, bool stillThere) async {
    HapticFeedback.mediumImpact();
    
    try {
      if (stillThere) {
        await _apiService.confirmAlert(
          alertId: alertId.toString(),
          confirmationType: 'confirmed',
        );
        
        // Also send via WebSocket for real-time updates
        _websocketService.confirmAlert(alertId.toString(), 'confirmed');
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Thank you for confirming!'),
              backgroundColor: const Color(0xFF10B981),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
        }
      } else {
        final success = await _apiService.confirmAlert(
          alertId: alertId.toString(),
          confirmationType: 'not_there',
        );
        
        // Also send via WebSocket for real-time updates
        _websocketService.confirmAlert(alertId.toString(), 'not_there');
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(success 
                  ? 'Alert marked as resolved - thank you for the feedback!' 
                  : 'Feedback recorded - thank you!'),
              backgroundColor: success ? const Color(0xFFEF4444) : const Color(0xFFF59E0B),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
        }
      }
      
      _fetchNearbyAlerts();
    } catch (e) {
      print('Error handling alert confirmation: $e');
    }
  }

  void _confirmAlert(Alert alert) async {
    if (alert.id != null) {
      // Immediate visual feedback
      setState(() {
        _confirmedReports.add(alert.id!);
      });
      
      // Haptic feedback
      HapticFeedback.heavyImpact();
      
      try {
        final success = await _apiService.confirmAlert(
          alertId: alert.id!.toString(),
          confirmationType: 'confirmed',
        );
        
        // Also send via WebSocket for real-time updates
        _websocketService.confirmAlert(alert.id!.toString(), 'confirmed');
        
        if (success) {
          _fetchNearbyAlerts();
          
          // Show success snackbar
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Alert confirmed! Thank you for helping the community.'),
                backgroundColor: const Color(0xFF10B981),
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
                margin: const EdgeInsets.all(16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            );
          }
        }
      } catch (e) {
        print('Error confirming alert: $e');
        // Alert confirmation was already added optimistically
      }
    }
  }

  Future<void> _addAlert(String type) async {
    if (!_isLocationReady) return;
    
    // Haptic feedback for reporting
    HapticFeedback.heavyImpact();
    
    try {
      final result = await _apiService.reportAlert(
        type: type,
        latitude: _currentLocation.latitude,
        longitude: _currentLocation.longitude,
      );
      
      // Also send via WebSocket for real-time updates
      _websocketService.reportAlert(type, _currentLocation.latitude, _currentLocation.longitude);
      
      if (result != null) {
        setState(() {
          if (!_alerts.any((a) => a.id == result.id)) {
            _alerts.add(result);
          }
        });
        _fetchNearbyAlerts();
        
        // Show success snackbar
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${_getAlertLabel(type)} reported successfully!'),
              backgroundColor: const Color(0xFF10B981),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
        }
      }
    } catch (e) {
      print('Error reporting alert: $e');
      final alert = Alert(
        type: type,
        latitude: _currentLocation.latitude,
        longitude: _currentLocation.longitude,
        reportedAt: DateTime.now(),
      );
      await _offlineStorage.saveAlert(alert);
      setState(() {
        _alerts.add(alert);
      });
      
      // Show offline snackbar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Alert saved offline. Will sync when connected.'),
            backgroundColor: const Color(0xFFF59E0B),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    }
  }
  
  String _getAlertLabel(String type) {
    switch (type) {
      case 'police':
        return 'Police';
      case 'roadwork':
        return 'Roadwork';
      case 'obstacle':
        return 'Obstacle';
      case 'accident':
        return 'Accident';
      case 'fire':
        return 'Fire';
      case 'traffic':
        return 'Traffic';
      default:
        return 'Alert';
    }
  }
  
  Alert _calculateAlertDistance(Alert alert) {
    if (!_isLocationReady) return alert;
    
    final Distance distance = Distance();
    final double distanceInMeters = distance(
      _currentLocation,
      LatLng(alert.latitude, alert.longitude),
    );
    
    return Alert(
      id: alert.id,
      type: alert.type,
      latitude: alert.latitude,
      longitude: alert.longitude,
      reportedAt: alert.reportedAt,
      confirmedCount: alert.confirmedCount,
      isActive: alert.isActive,
      distance: distanceInMeters,
    );
  }

  Alert? get _nextAlert {
    if (_alerts.isEmpty) return null;
    return _alerts.first;
  }
  
  void _switchView(String newView) {
    if (_currentView == newView) return;
    
    setState(() {
      _currentView = newView;
    });
    
    _viewTransitionController.reset();
    _viewTransitionController.forward();
    
    HapticFeedback.selectionClick();
  }
  
  void _toggleReportModal() {
    setState(() {
      _showReportModal = !_showReportModal;
    });
    
    if (_showReportModal) {
      _modalController.forward();
      HapticFeedback.mediumImpact();
    } else {
      _modalController.reverse();
    }
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
                                currentLatitude: _currentLocation.latitude,
                                currentLongitude: _currentLocation.longitude,
                              )
                            : MapViewNew(
                                currentLocation: _currentLocation,
                                alerts: _alerts,
                                currentSpeed: _currentSpeed,
                                nextAlert: _nextAlert,
                                isLocationReady: _isLocationReady,
                                isOnline: _isOnline,
                                currentHeading: _currentHeading,
                                onAlertConfirmation: _handleAlertConfirmation,
                              ),
                      ),
                    ],
                  ),
                ),
                
                // Modal overlay
                ReportModal(
                  currentLocation: _currentLocation,
                  onClose: _toggleReportModal,
                  onSubmitReport: (String type) {
                    _addAlert(type);
                    _toggleReportModal();
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
                                onPressed: () => _switchView(_currentView == 'map' ? 'meter' : 'map'),
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
                  
                  // Main content with transition animation
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      transitionBuilder: (Widget child, Animation<double> animation) {
                        return SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(1.0, 0.0),
                            end: Offset.zero,
                          ).animate(CurvedAnimation(
                            parent: animation,
                            curve: Curves.easeOutCubic,
                          )),
                          child: FadeTransition(
                            opacity: animation,
                            child: child,
                          ),
                        );
                      },
                      child: _currentView == 'meter'
                          ? MeterView(
                              key: const ValueKey('meter'),
                              currentSpeed: _currentSpeed,
                              nextAlert: _nextAlert,
                              alerts: _alerts,
                              confirmedReports: _confirmedReports,
                              onConfirmAlert: _confirmAlert,
                              currentLatitude: _currentLocation.latitude,
                              currentLongitude: _currentLocation.longitude,
                            )
                          : MapViewNew(
                              key: const ValueKey('map'),
                              currentLocation: _currentLocation,
                              alerts: _alerts,
                              currentSpeed: _currentSpeed,
                              nextAlert: _nextAlert,
                              isLocationReady: _isLocationReady,
                              isOnline: _isOnline,
                              currentHeading: _currentHeading,
                              onAlertConfirmation: _handleAlertConfirmation,
                            ),
                    ),
                  ),
                ],
              ),
            ),
      
      // Floating action button for reporting with animation
      floatingActionButton: AnimatedBuilder(
        animation: _modalController,
        builder: (context, child) {
          return Transform.scale(
            scale: _showReportModal ? 0.9 : 1.0,
            child: FloatingActionButton(
              onPressed: _toggleReportModal,
              backgroundColor: const Color(0xFFDC2626), // red-600
              child: AnimatedRotation(
                turns: _showReportModal ? 0.125 : 0,
                duration: const Duration(milliseconds: 300),
                child: Icon(
                  _showReportModal ? Icons.close : Icons.add,
                  color: Colors.white,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _viewTransitionController.dispose();
    _modalController.dispose();
    _locationService.dispose();
    _websocketService.dispose();
    _connectivityService.dispose();
    super.dispose();
  }
}