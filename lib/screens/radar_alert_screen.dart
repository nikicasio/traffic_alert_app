import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:math';
import '../models/alert.dart';
import '../services/real_api_service.dart';
import '../services/websocket_service.dart';
import '../services/device_location_service.dart';
import '../services/offline_storage.dart';
import '../services/connectivity_service.dart';
import '../services/notification_service.dart';
import '../services/speed_limit_service.dart';
import 'package:location/location.dart';
import 'package:latlong2/latlong.dart';
import 'meter_view.dart';
import 'map_view_new.dart';
import '../widgets/report_modal.dart';
import '../widgets/app_menu.dart';
import '../widgets/still_there_dialog.dart';
import '../widgets/road_name_bar.dart';

class RadarAlertScreen extends StatefulWidget {
  @override
  _RadarAlertScreenState createState() => _RadarAlertScreenState();
}

class _RadarAlertScreenState extends State<RadarAlertScreen> 
    with TickerProviderStateMixin, WidgetsBindingObserver {
  // View state
  String _currentView = 'meter'; // 'meter' or 'map'
  bool _showReportModal = false;
  bool _showMenu = false;
  
  // Services
  final DeviceLocationService _locationService = DeviceLocationService();
  final RealApiService _apiService = RealApiService();
  final WebSocketService _websocketService = WebSocketService();
  final OfflineStorage _offlineStorage = OfflineStorage();
  final ConnectivityService _connectivityService = ConnectivityService();
  final NotificationService _notificationService = NotificationService();
  
  // State variables
  List<Alert> _alerts = [];
  LatLng _currentLocation = LatLng(0.0, 0.0); // No default location - must wait for GPS
  bool _isLocationReady = false;
  bool _isOnline = true;
  bool _isReconnecting = false;
  double _currentSpeed = 0;
  double _currentHeading = 0;
  Set<int> _confirmedReports = <int>{};
  SpeedLimitResult? _currentSpeedLimit;
  
  // Still there dialog state
  Alert? _stillThereAlert;
  bool _showStillThereDialog = false;
  Set<int> _alertsShownStillThere = <int>{};
  
  // Debouncing for API calls
  Timer? _fetchAlertsDebouncer;
  DateTime? _lastFetchTime;
  
  // Periodic alert fetching
  Timer? _periodicFetchTimer;
  
  // Animation controllers
  late AnimationController _viewTransitionController;
  late AnimationController _modalController;
  late Animation<double> _viewFadeAnimation;
  late Animation<Offset> _viewSlideAnimation;
  late Animation<double> _modalAnimation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
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
      // Initialize services in the correct order with individual error handling
      print('🔄 Step 1: Initializing notification service...');
      try {
        await _notificationService.initialize().timeout(const Duration(seconds: 10));
        print('✅ Step 1: Notification service initialized');
      } catch (e) {
        print('⚠️ Step 1: Notification service failed: $e - continuing');
      }
      
      print('🔄 Step 2: Initializing API service...');
      try {
        await _apiService.initialize().timeout(const Duration(seconds: 10));
        print('✅ Step 2: API service initialized');
      } catch (e) {
        print('⚠️ Step 2: API service failed: $e - continuing');
      }
      
      print('🔄 Step 3: Initializing location service...');
      try {
        await _locationService.initialize().timeout(const Duration(seconds: 15));
        print('✅ Step 3: Location service initialized');
      } catch (e) {
        print('⚠️ Step 3: Location service failed: $e - continuing');
      }
      
      print('🔄 Step 4: Initializing WebSocket service...');
      try {
        // Initialize WebSocket with authentication if available
        if (_apiService.isAuthenticated) {
          final userProfile = await _apiService.getUserProfile();
          final userId = userProfile?['id']?.toString();
          final authToken = _apiService.authToken;
          
          if (userId != null && authToken != null) {
            await _websocketService.initialize(userId: userId, authToken: authToken).timeout(const Duration(seconds: 10));
          } else {
            await _websocketService.initialize().timeout(const Duration(seconds: 10));
          }
        } else {
          await _websocketService.initialize().timeout(const Duration(seconds: 10));
        }
        print('✅ Step 4: WebSocket service initialized');
      } catch (e) {
        print('⚠️ Step 4: WebSocket failed: $e - continuing without WebSocket');
      }
      
      // Update FCM token on server after authentication
      print('🔄 Step 5: Updating FCM token on server...');
      try {
        await _notificationService.updateTokenOnServer().timeout(const Duration(seconds: 5));
        print('✅ Step 5: FCM token updated');
      } catch (e) {
        print('⚠️ Step 5: FCM token update failed: $e - continuing');
      }
      
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
        // Only update if we have valid coordinates
        if (location.latitude != null && location.longitude != null && 
            location.latitude != 0.0 && location.longitude != 0.0) {
          final wasLocationReady = _isLocationReady;
          final oldLocation = _currentLocation;
          
          setState(() {
            _currentLocation = LatLng(location.latitude!, location.longitude!);
            _currentSpeed = location.speed ?? 0;
            _currentHeading = location.heading ?? 0;
            if (!_isLocationReady) _isLocationReady = true;
          });
          
          print('📍 Valid location update: ${location.latitude}, ${location.longitude}, ${location.speed ?? 0} km/h');
          
          // Calculate distance from previous location
          final distanceFromPrevious = _calculateDistance(oldLocation, _currentLocation);
          
          // If this is the first valid location, immediately fetch alerts
          if (!wasLocationReady && _isLocationReady) {
            print('🎯 Location ready for first time - immediate fetch!');
            _forceImmediateFetchAlerts();
          } 
          // Always fetch when location changes (remove distance restriction)
          else {
            print('🎯 Location updated (${distanceFromPrevious.toStringAsFixed(0)}m change) - fetching alerts...');
            _fetchNearbyAlerts(); // Use regular fetch instead of debounced
          }
        } else {
          print('⚠️ Received invalid location: ${location.latitude}, ${location.longitude} - ignoring');
        }
        
        // Update WebSocket location subscriptions only for valid coordinates
        if (location.latitude != null && location.longitude != null && 
            location.latitude != 0.0 && location.longitude != 0.0) {
          _websocketService.subscribeToLocationUpdates(
            location.latitude!,
            location.longitude!,
            radiusKm: 10,
          );
          _websocketService.updateUserLocation(location.latitude!, location.longitude!);
          
          _checkStillThereDialog();
        }
      });
      
      // Listen to speed limit updates
      _locationService.speedLimitStream.listen((SpeedLimitResult? speedLimit) {
        setState(() {
          _currentSpeedLimit = speedLimit;
        });
        
        if (speedLimit?.hasSpeedLimit == true) {
          print('🚦 Speed limit updated: ${speedLimit!.speedLimitKmh} km/h on ${speedLimit.roadType}');
        }
      });
      
      // Check API health with retry
      print('🔍 Checking API health...');
      final isHealthy = await _apiService.checkHealth(maxRetries: 2);
      print('API Health: $isHealthy');
      
      if (!isHealthy) {
        print('⚠️ API health check failed, but continuing with initialization');
        setState(() {
          _isOnline = false;
        });
      }
      
      // Setup WebSocket event listeners
      _setupWebSocketListeners();
      
      // Initial data loading - SMART SINGLE FETCH
      print('🔄 Step 6: Loading initial data with real-time fetching...');
      try {
        setState(() {
          _isOnline = true;
        });
        
        // Wait a moment for location to be ready, then do ONE smart fetch
        Timer(const Duration(milliseconds: 500), () async {
          print('🚀 SMART FETCH: Single optimized fetch with best available location...');
          await _forceImmediateFetchAlerts();
        });
        
        // Start real-time periodic fetching immediately
        _startPeriodicFetching();
        
        print('✅ Step 6: Real-time alert system started');
      } catch (e) {
        print('⚠️ Step 6: Initial data loading failed: $e - loading local data');
        await _loadLocalAlerts();
        // Still start periodic fetching even if initial failed
        _startPeriodicFetching();
      }
      
    } catch (e) {
      print('❌ Critical error during initialization: $e');
      setState(() {
        _isOnline = false;
      });
      // Try to load local data as fallback
      try {
        await _loadLocalAlerts();
      } catch (localError) {
        print('❌ Error loading local alerts: $localError');
        // Set empty alerts list if even local loading fails
        setState(() {
          _alerts = [];
        });
      }
    } finally {
      // Ensure UI loads regardless of what happens above
      print('🏁 Initialization complete - ensuring UI is ready');
      if (mounted) {
        setState(() {
          _isLocationReady = true; // Force UI to show even if location service failed
          _isReconnecting = false; // Make sure reconnecting screen doesn't block UI
        });
        
      }
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
            _debouncedFetchAlerts();
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

  void _debouncedFetchAlerts() {
    _fetchAlertsDebouncer?.cancel();
    _fetchAlertsDebouncer = Timer(const Duration(seconds: 10), () {
      _fetchNearbyAlerts();
    });
  }
  
  // Start periodic fetching every 5 seconds for real-time alerts
  void _startPeriodicFetching() {
    _periodicFetchTimer?.cancel();
    _periodicFetchTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      print('🔄 PERIODIC FETCH: Real-time fetching every 5 seconds...');
      await _fetchNearbyAlerts();
    });
    print('✅ Real-time periodic fetching started (every 5 seconds)');
  }
  
  // Stop periodic fetching
  void _stopPeriodicFetching() {
    _periodicFetchTimer?.cancel();
    _periodicFetchTimer = null;
    print('🛑 Periodic fetching stopped');
  }

  // Force immediate fetch with cache clear and no throttling
  Future<void> _forceImmediateFetchAlerts() async {
    print('🚀 FORCE FETCH: Immediate alert fetch requested');
    final previousFetchTime = _lastFetchTime;
    _lastFetchTime = null; // Reset to bypass throttling
    _apiService.clearCache(); // Clear API cache
    await _fetchNearbyAlerts();
    // Don't restore the previous fetch time - allow subsequent fetches
  }

  Future<void> _fetchNearbyAlerts() async {
    // Only fetch if we have valid GPS location - no fallbacks
    if (!_isLocationReady || 
        _currentLocation.latitude == 0.0 || 
        _currentLocation.longitude == 0.0) {
      print('⚠️ No valid GPS location available - skipping alert fetch');
      return;
    }
    
    LatLng locationToUse = _currentLocation;
    print('📍 Using GPS location: ${locationToUse.latitude}, ${locationToUse.longitude}');
    
    // Allow more frequent fetches (within 10 seconds only)
    final now = DateTime.now();
    if (_lastFetchTime != null && 
        now.difference(_lastFetchTime!) < const Duration(seconds: 10)) {
      print('Skipping fetch - too recent (${now.difference(_lastFetchTime!).inSeconds}s ago)');
      return;
    }
    
    _lastFetchTime = now;
    
    try {
      print('🔍 Fetching alerts from API...');
      print('📍 Location: ${locationToUse.latitude}, ${locationToUse.longitude}');
      print('🔐 Authenticated: ${_apiService.isAuthenticated}');
      
      final alerts = await _apiService.getNearbyAlerts(
        latitude: locationToUse.latitude,
        longitude: locationToUse.longitude,
        radius: 10000,
      );
      
      setState(() {
        _alerts = alerts;
        _isOnline = true;
      });
      print('✅ Fetched ${alerts.length} alerts successfully');
      print('🔄 Updated _alerts list in radar screen state');
      
      // Log each alert for debugging
      for (int i = 0; i < alerts.length; i++) {
        final alert = alerts[i];
        print('   Alert ${i + 1}: ID ${alert.id}, Type: ${alert.type}, Location: ${alert.latitude}, ${alert.longitude}');
      }
      
      // Also log the current state after setState
      print('📊 Current _alerts state contains ${_alerts.length} alerts');
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
      
      _forceImmediateFetchAlerts();
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
          _forceImmediateFetchAlerts();
          
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
        _forceImmediateFetchAlerts();
        
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

  void _toggleMenu() {
    setState(() {
      _showMenu = !_showMenu;
    });
    HapticFeedback.selectionClick();
  }

  // Calculate distance between two points in meters
  double _calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371000; // Earth's radius in meters
    
    double lat1Rad = point1.latitude * (pi / 180);
    double lat2Rad = point2.latitude * (pi / 180);
    double deltaLatRad = (point2.latitude - point1.latitude) * (pi / 180);
    double deltaLngRad = (point2.longitude - point1.longitude) * (pi / 180);

    double a = sin(deltaLatRad / 2) * sin(deltaLatRad / 2) +
        cos(lat1Rad) * cos(lat2Rad) *
        sin(deltaLngRad / 2) * sin(deltaLngRad / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  // Check if we should show "Still there?" dialog
  void _checkStillThereDialog() {
    if (!_isLocationReady || _alerts.isEmpty || _showStillThereDialog) return;

    for (Alert alert in _alerts) {
      // Skip if we've already shown dialog for this alert
      if (_alertsShownStillThere.contains(alert.id)) continue;
      
      // Skip if user already confirmed this alert
      if (_confirmedReports.contains(alert.id)) continue;

      LatLng alertLocation = LatLng(alert.latitude, alert.longitude);
      double distance = _calculateDistance(_currentLocation, alertLocation);

      // Show dialog when within 10 meters of alert
      if (distance <= 10.0) {
        setState(() {
          _stillThereAlert = alert;
          _showStillThereDialog = true;
        });
        
        // Mark this alert as shown
        _alertsShownStillThere.add(alert.id!);
        break; // Only show one dialog at a time
      }
    }
  }

  // Handle still there dialog confirmation
  void _handleStillThereConfirmation(int alertId, bool isStillThere) {
    // Find the alert object
    Alert? alert = _alerts.firstWhere((a) => a.id == alertId, orElse: () => _stillThereAlert!);
    
    if (isStillThere) {
      // User confirmed alert is still there
      _confirmedReports.add(alertId);
      _confirmAlert(alert);
    } else {
      // User said alert is not there - dismiss it
      _dismissAlert(alert);
    }
    
    _dismissStillThereDialog();
  }

  // Handle dismissing an alert (when user says it's not there)
  void _dismissAlert(Alert alert) async {
    if (alert.id != null) {
      setState(() {
        _confirmedReports.add(alert.id!);
      });
      
      HapticFeedback.lightImpact();
      
      try {
        final success = await _apiService.confirmAlert(
          alertId: alert.id!.toString(),
          confirmationType: 'not_there',
        );
        
        // Also send via WebSocket
        _websocketService.confirmAlert(alert.id!.toString(), 'not_there');
        
        if (success) {
          // Remove from local alerts list
          setState(() {
            _alerts.removeWhere((a) => a.id == alert.id);
          });
        }
      } catch (e) {
        print('Error dismissing alert: $e');
      }
    }
  }

  // Dismiss the still there dialog
  void _dismissStillThereDialog() {
    setState(() {
      _showStillThereDialog = false;
      _stillThereAlert = null;
    });
  }

  Widget _buildReconnectingScreen() {
    return Container(
      color: const Color(0xFF111827), // gray-900
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 60,
              height: 60,
              child: CircularProgressIndicator(
                strokeWidth: 4,
                valueColor: AlwaysStoppedAnimation<Color>(
                  const Color(0xFF10B981), // green-500
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Reconnecting to server...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Please wait while we restore your connection',
              style: TextStyle(
                color: Color(0xFF9CA3AF), // gray-400
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF1F2937), // gray-800
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'RadarAlert',
                style: TextStyle(
                  color: Color(0xFF10B981), // green-500
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: const Color(0xFF1F2937), // gray-800
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Menu button
          IconButton(
            onPressed: _toggleMenu,
            icon: const Icon(
              Icons.menu,
              color: Colors.white,
            ),
          ),
          // Centered title with online status
          Column(
            children: [
              const Text(
                'RadarAlert',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isReconnecting)
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          const Color(0xFFF59E0B), // yellow
                        ),
                      ),
                    )
                  else
                    Icon(
                      _isOnline ? Icons.wifi : Icons.wifi_off,
                      color: _isOnline ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                      size: 12,
                    ),
                  const SizedBox(width: 4),
                  Text(
                    _isReconnecting
                        ? 'Reconnecting...'
                        : (_isOnline ? 'Online' : 'Offline'),
                    style: TextStyle(
                      color: _isReconnecting
                          ? const Color(0xFFF59E0B) // yellow
                          : (_isOnline ? const Color(0xFF10B981) : const Color(0xFFEF4444)),
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
          // View toggle button
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111827), // gray-900
      body: Stack(
        children: [
          // Main content
          SafeArea(
            child: Column(
              children: [
                // Header
                _buildHeader(),
                
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
                    child: () {
                      print('🎯 UI State: reconnecting=$_isReconnecting, locationReady=$_isLocationReady, view=$_currentView, location=(${_currentLocation.latitude}, ${_currentLocation.longitude}), alerts=${_alerts.length}');
                      
                      if (_isReconnecting && !_isLocationReady) {
                        return _buildReconnectingScreen();
                      } else if (_currentView == 'meter') {
                        return MeterView(
                                key: const ValueKey('meter'),
                                currentSpeed: _currentSpeed,
                                nextAlert: _nextAlert,
                                alerts: _alerts,
                                confirmedReports: _confirmedReports,
                                onConfirmAlert: _confirmAlert,
                                currentLatitude: _currentLocation.latitude,
                                currentLongitude: _currentLocation.longitude,
                                speedLimit: _currentSpeedLimit,
                              );
                      } else {
                        return MapViewNew(
                          key: const ValueKey('map'),
                          currentLocation: _currentLocation,
                          alerts: _alerts,
                          currentSpeed: _currentSpeed,
                          nextAlert: _nextAlert,
                          isLocationReady: _isLocationReady,
                          isOnline: _isOnline,
                          currentHeading: _currentHeading,
                          speedLimit: _currentSpeedLimit,
                          onAlertConfirmation: _handleAlertConfirmation,
                        );
                      }
                    }(),
                  ),
                ),
              ],
            ),
          ),
          
          // Report Modal
          if (_showReportModal)
            ReportModal(
              currentLocation: _currentLocation,
              onClose: _toggleReportModal,
              onSubmitReport: (String type) {
                _addAlert(type);
                _toggleReportModal();
              },
            ),
            
          // Side Menu
          if (_showMenu)
            GestureDetector(
              onTap: _toggleMenu,
              child: Container(
                color: Colors.black54,
                child: Row(
                  children: [
                    AppMenu(
                      onProfileUpdate: () {
                        // Refresh any profile-dependent state if needed
                      },
                    ),
                    const Spacer(),
                  ],
                ),
              ),
            ),
            
          // Still There Dialog
          if (_showStillThereDialog && _stillThereAlert != null)
            StillThereDialog(
              alert: _stillThereAlert!,
              onConfirmation: _handleStillThereConfirmation,
              onDismiss: _dismissStillThereDialog,
            ),
            
          // Road Name Bar (only show on map view)
          if (_currentView == 'map')
            RoadNameBar(
              currentLocation: _currentLocation,
              isLocationReady: _isLocationReady,
            ),
        ],
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
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    switch (state) {
      case AppLifecycleState.resumed:
        print('🔄 App resumed - reconnecting services and refreshing data');
        // Add small delay to ensure Flutter engine is ready
        Future.delayed(const Duration(milliseconds: 500), () {
          _handleAppResume();
        });
        break;
      case AppLifecycleState.paused:
        print('⏸️ App paused - reducing background activity');
        _handleAppPause();
        break;
      case AppLifecycleState.detached:
        print('🔌 App detached - stopping all background services');
        _handleAppDetach();
        break;
      case AppLifecycleState.inactive:
        print('💤 App inactive - reducing activity');
        _handleAppInactive();
        break;
      case AppLifecycleState.hidden:
        print('👻 App hidden - minimal background activity');
        _handleAppHidden();
        break;
    }
  }

  Future<void> _handleAppResume() async {
    if (!mounted) return;
    
    setState(() {
      _isReconnecting = true;
    });
    
    try {
      print('🔄 Flutter App Resume: Starting lightweight reconnection...');
      
      // Simplified resume process to prevent system killing
      await Future.delayed(const Duration(milliseconds: 100));
      
      // 1. Quick API health check (simplified)
      print('🏥 Quick API health check...');
      final isHealthy = await _apiService.checkHealth(maxRetries: 1);
      
      // 2. Lightweight WebSocket reconnect
      print('🔌 Reconnecting WebSocket...');
      try {
        await _websocketService.disconnect();
        await Future.delayed(const Duration(milliseconds: 500));
        
        if (_apiService.isAuthenticated) {
          final userProfile = await _apiService.getUserProfile();
          final userId = userProfile?['id']?.toString();
          final authToken = _apiService.authToken;
          
          if (userId != null && authToken != null) {
            await _websocketService.initialize(userId: userId, authToken: authToken);
          } else {
            await _websocketService.initialize();
          }
        } else {
          await _websocketService.initialize();
        }
        print('✅ Step 3: WebSocket reconnected');
      } catch (e) {
        print('❌ Step 3: WebSocket reconnection failed: $e');
      }
      
      // 4. Restart location service if stopped
      print('📍 Step 4: Checking location service...');
      if (!_isLocationReady) {
        print('📍 Location service not ready, reinitializing...');
        await _locationService.initialize();
      } else {
        print('✅ Step 4: Location service ready');
      }
      
      // 5. Force refresh data regardless AND restart periodic fetching
      print('🔄 Step 5: Force refreshing data and restarting periodic fetching...');
      try {
        await _forceImmediateFetchAlerts();
        _startPeriodicFetching(); // Restart periodic fetching
        
        // Resubscribe to location updates
        if (_isLocationReady) {
          _websocketService.subscribeToLocationUpdates(
            _currentLocation.latitude,
            _currentLocation.longitude,
            radiusKm: 10,
          );
        }
      } catch (e) {
        print('❌ Step 5: Data refresh failed: $e');
        await _loadLocalAlerts();
        _startPeriodicFetching(); // Still start periodic fetching
      }
      
      // 6. Update UI state
      if (mounted) {
        setState(() {
          _isOnline = true;
          _isReconnecting = false;
        });
      }
      
      print('✅ Flutter App Resume: All steps completed successfully');
      
    } catch (e) {
      print('❌ Flutter App Resume: Critical error during reconnection: $e');
      // Emergency fallback
      try {
        await _loadLocalAlerts();
        _startPeriodicFetching(); // Still start periodic fetching
      } catch (localError) {
        print('❌ Even local alerts failed: $localError');
      }
      
      if (mounted) {
        setState(() {
          _isOnline = false;
          _isReconnecting = false;
        });
      }
    }
  }

  void _handleAppPause() {
    // Reduce background activity to prevent system killing the app
    _fetchAlertsDebouncer?.cancel();
    _stopPeriodicFetching();
    print('🔇 Paused background alert fetching');
  }

  void _handleAppInactive() {
    // Similar to pause but less aggressive
    _fetchAlertsDebouncer?.cancel();
    print('🔇 Reduced background activity');
  }

  void _handleAppHidden() {
    // App is hidden but might be restored quickly
    _fetchAlertsDebouncer?.cancel();
    print('🔇 Minimized background activity');
  }

  void _handleAppDetach() {
    // App is being fully closed - stop everything
    try {
      _fetchAlertsDebouncer?.cancel();
      _stopPeriodicFetching();
      _websocketService.disconnect();
      print('🛑 Stopped all background services');
    } catch (e) {
      print('Error during app detach: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _fetchAlertsDebouncer?.cancel();
    _stopPeriodicFetching();
    _viewTransitionController.dispose();
    _modalController.dispose();
    _locationService.dispose();
    _websocketService.dispose();
    _connectivityService.dispose();
    super.dispose();
  }
}