import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/alert.dart';
import '../services/mock_data_service.dart';
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
  final MockDataService _dataService = MockDataService();
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
      _dataService.initialize();
      await _locationService.initialize();
      
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
        
        _fetchNearbyAlerts();
      });
      
      // Data service event listeners
      _dataService.newAlertStream.listen((alert) {
        setState(() {
          if (!_alerts.any((a) => a.id == alert.id)) {
            _alerts.add(alert);
          }
        });
      });
      
      _dataService.alertConfirmedStream.listen((data) {
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

  Future<void> _fetchNearbyAlerts() async {
    if (!_isLocationReady) return;
    
    try {
      final alerts = _dataService.getNearbyAlerts(
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
        final result = await _dataService.reportAlert(
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

  void _handleAlertConfirmation(int alertId, bool stillThere) async {
    HapticFeedback.mediumImpact();
    
    try {
      if (stillThere) {
        await _dataService.confirmAlertStillThere(alertId);
        
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
        final removed = await _dataService.reportAlertNotThere(alertId);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(removed 
                  ? 'Alert removed - thank you for the feedback!' 
                  : 'Feedback recorded - thank you!'),
              backgroundColor: removed ? const Color(0xFFEF4444) : const Color(0xFFF59E0B),
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
        final success = await _dataService.confirmAlert(alert.id!);
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
      final result = await _dataService.reportAlert(
        type,
        _currentLocation.latitude,
        _currentLocation.longitude,
      );
      
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
    _dataService.dispose();
    _connectivityService.dispose();
    super.dispose();
  }
}