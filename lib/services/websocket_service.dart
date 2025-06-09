import 'dart:async';
import 'dart:convert';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../models/alert.dart';
import 'real_api_service.dart';

class WebSocketService {
  static const String socketUrl = 'http://192.168.0.50:8000'; // Update with your server IP
  
  IO.Socket? _socket;
  final RealApiService _apiService = RealApiService();
  
  // Stream controllers for different events
  final _alertCreatedController = StreamController<Alert>.broadcast();
  final _alertConfirmedController = StreamController<Map<String, dynamic>>.broadcast();
  final _alertDismissedController = StreamController<Map<String, dynamic>>.broadcast();
  final _connectionStatusController = StreamController<bool>.broadcast();
  
  // Public streams
  Stream<Alert> get alertCreatedStream => _alertCreatedController.stream;
  Stream<Map<String, dynamic>> get alertConfirmedStream => _alertConfirmedController.stream;
  Stream<Map<String, dynamic>> get alertDismissedStream => _alertDismissedController.stream;
  Stream<bool> get connectionStatusStream => _connectionStatusController.stream;
  
  bool _isConnected = false;
  List<String> _subscribedChannels = [];
  
  // Singleton pattern
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  WebSocketService._internal();

  Future<void> initialize() async {
    print('Initializing WebSocket service...');
    await _connect();
  }

  Future<void> _connect() async {
    try {
      _socket = IO.io(socketUrl, 
        IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setExtraHeaders({
            'Authorization': _apiService.isAuthenticated 
                ? 'Bearer ${_apiService.authToken}' 
                : null,
          })
          .build()
      );

      _socket!.onConnect((_) {
        print('WebSocket connected');
        _isConnected = true;
        _connectionStatusController.add(true);
        _subscribeToGlobalChannels();
      });

      _socket!.onDisconnect((_) {
        print('WebSocket disconnected');
        _isConnected = false;
        _connectionStatusController.add(false);
      });

      _socket!.onConnectError((error) {
        print('WebSocket connection error: $error');
        _isConnected = false;
        _connectionStatusController.add(false);
      });

      // Listen to alert events
      _socket!.on('alert.created', _handleAlertCreated);
      _socket!.on('alert.confirmed', _handleAlertConfirmed);
      _socket!.on('alert.dismissed', _handleAlertDismissed);
      _socket!.on('alert.expired', _handleAlertExpired);

      _socket!.connect();
    } catch (e) {
      print('Failed to initialize WebSocket: $e');
      _connectionStatusController.add(false);
    }
  }

  void _subscribeToGlobalChannels() {
    if (!_isConnected) return;
    
    // Subscribe to global alerts channel
    _subscribeToChannel('alerts.global');
  }

  void subscribeToLocationUpdates(double latitude, double longitude, {int radiusKm = 10}) {
    if (!_isConnected) return;
    
    // Calculate location-based channel name (same logic as backend)
    final gridLat = (latitude * 100).round() / 100;
    final gridLng = (longitude * 100).round() / 100;
    final channelName = 'alerts.location.${gridLat.toString().replaceAll('.', '_').replaceAll('-', 'n')}_${gridLng.toString().replaceAll('.', '_').replaceAll('-', 'n')}';
    
    _subscribeToChannel(channelName);
    
    // Subscribe to nearby channels for broader coverage
    final nearbyChannels = _generateNearbyChannels(latitude, longitude, radiusKm);
    for (final channel in nearbyChannels) {
      _subscribeToChannel(channel);
    }
  }

  void subscribeToAlertTypes(List<String> alertTypes) {
    if (!_isConnected) return;
    
    for (final type in alertTypes) {
      _subscribeToChannel('alerts.type.$type');
    }
  }

  void _subscribeToChannel(String channelName) {
    if (_subscribedChannels.contains(channelName)) return;
    
    _socket!.emit('subscribe', {'channel': channelName});
    _subscribedChannels.add(channelName);
    print('Subscribed to channel: $channelName');
  }

  void _unsubscribeFromChannel(String channelName) {
    if (!_subscribedChannels.contains(channelName)) return;
    
    _socket!.emit('unsubscribe', {'channel': channelName});
    _subscribedChannels.remove(channelName);
    print('Unsubscribed from channel: $channelName');
  }

  List<String> _generateNearbyChannels(double latitude, double longitude, int radiusKm) {
    final channels = <String>[];
    const gridSize = 0.01; // ~1km grid
    final gridRadius = (radiusKm / 111).ceil(); // Approximate km per degree

    for (int latOffset = -gridRadius; latOffset <= gridRadius; latOffset++) {
      for (int lngOffset = -gridRadius; lngOffset <= gridRadius; lngOffset++) {
        final gridLat = ((latitude + (latOffset * gridSize)) * 100).round() / 100;
        final gridLng = ((longitude + (lngOffset * gridSize)) * 100).round() / 100;
        
        final channelName = 'alerts.location.${gridLat.toString().replaceAll('.', '_').replaceAll('-', 'n')}_${gridLng.toString().replaceAll('.', '_').replaceAll('-', 'n')}';
        channels.add(channelName);
      }
    }

    return channels.toSet().toList(); // Remove duplicates
  }

  void _handleAlertCreated(dynamic data) {
    try {
      print('Received alert.created: $data');
      
      if (data is Map<String, dynamic> && data['alert'] != null) {
        final alert = Alert.fromJson(data['alert']);
        _alertCreatedController.add(alert);
      }
    } catch (e) {
      print('Error handling alert.created: $e');
    }
  }

  void _handleAlertConfirmed(dynamic data) {
    try {
      print('Received alert.confirmed: $data');
      
      if (data is Map<String, dynamic>) {
        _alertConfirmedController.add(Map<String, dynamic>.from(data));
      }
    } catch (e) {
      print('Error handling alert.confirmed: $e');
    }
  }

  void _handleAlertDismissed(dynamic data) {
    try {
      print('Received alert.dismissed: $data');
      
      if (data is Map<String, dynamic>) {
        _alertDismissedController.add(Map<String, dynamic>.from(data));
      }
    } catch (e) {
      print('Error handling alert.dismissed: $e');
    }
  }

  void _handleAlertExpired(dynamic data) {
    try {
      print('Received alert.expired: $data');
      
      if (data is Map<String, dynamic>) {
        // Treat expired alerts as dismissed
        _alertDismissedController.add({
          'alert_id': data['alert_id'],
          'event_type': 'alert_expired',
          'should_remove': true,
        });
      }
    } catch (e) {
      print('Error handling alert.expired: $e');
    }
  }

  // Send events
  void reportAlert(String type, double latitude, double longitude) {
    if (!_isConnected) return;
    
    _socket!.emit('report_alert', {
      'type': type,
      'latitude': latitude,
      'longitude': longitude,
    });
  }

  void confirmAlert(String alertId, String confirmationType) {
    if (!_isConnected) return;
    
    _socket!.emit('confirm_alert', {
      'alert_id': alertId,
      'confirmation_type': confirmationType,
    });
  }

  void updateUserLocation(double latitude, double longitude) {
    if (!_isConnected) return;
    
    _socket!.emit('location_update', {
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  // Connection management
  void reconnect() {
    if (_socket != null) {
      _socket!.disconnect();
      _subscribedChannels.clear();
    }
    _connect();
  }

  void disconnect() {
    if (_socket != null) {
      _socket!.disconnect();
      _socket!.dispose();
      _socket = null;
    }
    _isConnected = false;
    _subscribedChannels.clear();
    _connectionStatusController.add(false);
  }

  // Getters
  bool get isConnected => _isConnected;
  List<String> get subscribedChannels => List.from(_subscribedChannels);

  // Clean up
  void dispose() {
    disconnect();
    _alertCreatedController.close();
    _alertConfirmedController.close();
    _alertDismissedController.close();
    _connectionStatusController.close();
  }
}