import 'dart:async';
import 'dart:convert';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../models/alert.dart';
import 'real_api_service.dart';

class WebSocketService {
  static const String socketUrl = 'http://159.69.41.118:3001';
  
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
  String? _userId;
  String? _authToken;
  List<String> _subscribedChannels = [];
  
  // Singleton pattern
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  WebSocketService._internal();

  Future<void> initialize({String? userId, String? authToken}) async {
    if (_isConnected && _socket != null) {
      print('WebSocket already connected, skipping initialization');
      return;
    }
    
    print('Initializing Socket.IO WebSocket service...');
    _userId = userId;
    _authToken = authToken;
    await _connect();
  }

  Future<void> updateAuthentication(String userId, String authToken) async {
    print('Updating Socket.IO authentication - userId: $userId, token: ${authToken.substring(0, 10)}...');
    _userId = userId;
    _authToken = authToken;
    
    if (_isConnected) {
      // Re-authenticate with new credentials
      _socket!.emit('authenticate', {
        'userId': userId,
        'authToken': authToken,
      });
      print('Sent authenticate event to Socket.IO server');
    } else {
      print('Socket not connected, reconnecting...');
      // Reconnect with new credentials
      await reconnect();
    }
  }

  Future<void> _connect() async {
    // Disconnect existing socket if any
    if (_socket != null) {
      print('Disconnecting existing socket before creating new one');
      _socket!.disconnect();
      _socket = null;
    }
    
    try {
      _socket = IO.io(socketUrl, IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setAuth({
            if (_userId != null) 'userId': _userId,
            if (_authToken != null) 'authToken': _authToken,
          })
          .build());

      _socket!.onConnect((data) {
        print('Connected to Socket.IO server');
        _isConnected = true;
        
        // Only add to controller if it's not closed
        if (!_connectionStatusController.isClosed) {
          _connectionStatusController.add(true);
        }
        
        // Authenticate if we have credentials
        if (_userId != null && _authToken != null) {
          _socket!.emit('authenticate', {
            'userId': _userId,
            'authToken': _authToken,
          });
        }
      });

      _socket!.onDisconnect((data) {
        print('Disconnected from Socket.IO server: $data');
        _isConnected = false;
        
        // Only add to controller if it's not closed
        if (!_connectionStatusController.isClosed) {
          _connectionStatusController.add(false);
        }
        _subscribedChannels.clear();
      });

      _socket!.on('authenticated', (data) {
        print('✅ Successfully authenticated with Socket.IO server: $data');
        // Subscribe to global channels after authentication
        _subscribeToGlobalChannels();
      });

      _socket!.on('authentication_failed', (data) {
        print('❌ Authentication failed: $data');
        // Mark as disconnected for authentication failure
        _isConnected = false;
        if (!_connectionStatusController.isClosed) {
          _connectionStatusController.add(false);
        }
      });

      _socket!.on('error', (data) {
        print('Socket.IO error: $data');
        
        // Handle authentication errors specifically
        if (data is Map && data['message'] == 'Not authenticated') {
          print('Authentication error - attempting to re-authenticate');
          if (_userId != null && _authToken != null) {
            _socket!.emit('authenticate', {
              'userId': _userId,
              'authToken': _authToken,
            });
          }
        }
        
        if (!_connectionStatusController.isClosed) {
          _connectionStatusController.add(false);
        }
      });

      _socket!.on('connect_error', (data) {
        print('Socket.IO connection error: $data');
        if (!_connectionStatusController.isClosed) {
          _connectionStatusController.add(false);
        }
      });

      // Listen for alert events
      _socket!.on('alert.created', (data) {
        print('Received alert.created: $data');
        _handleAlertCreated(data);
      });

      _socket!.on('alert.confirmed', (data) {
        print('Received alert.confirmed: $data');
        _handleAlertConfirmed(data);
      });

      _socket!.on('subscribed', (data) {
        print('Subscribed to channel: ${data['channel']}');
      });

      _socket!.on('unsubscribed', (data) {
        print('Unsubscribed from channel: ${data['channel']}');
      });

      _socket!.connect();
      
    } catch (e) {
      print('Failed to initialize Socket.IO: $e');
      if (!_connectionStatusController.isClosed) {
        _connectionStatusController.add(false);
      }
    }
  }

  void _subscribeToGlobalChannels() {
    if (!_isConnected) return;
    
    // Subscribe to global alerts channel
    _subscribeToChannel('alerts.global');
  }

  Future<void> subscribeToLocationUpdates(double latitude, double longitude, {int radiusKm = 10}) async {
    if (!_isConnected) return;
    
    // Calculate location-based channel name (same logic as backend)
    final gridLat = (latitude * 100).round() / 100;
    final gridLng = (longitude * 100).round() / 100;
    final channelName = 'alerts.location.${gridLat}_$gridLng';
    
    await _subscribeToChannel(channelName);
    
    // Subscribe to nearby channels for broader coverage
    final nearbyChannels = _generateNearbyChannels(latitude, longitude, radiusKm);
    for (final channel in nearbyChannels) {
      await _subscribeToChannel(channel);
    }
    
    // Send location update to server
    updateUserLocation(latitude, longitude);
  }

  Future<void> subscribeToAlertTypes(List<String> alertTypes) async {
    if (!_isConnected) return;
    
    for (final type in alertTypes) {
      await _subscribeToChannel('alerts.type.$type');
    }
  }

  Future<void> _subscribeToChannel(String channelName) async {
    if (_subscribedChannels.contains(channelName)) return;
    
    try {
      _socket!.emit('subscribe', {'channel': channelName});
      _subscribedChannels.add(channelName);
      print('Requested subscription to channel: $channelName');
    } catch (e) {
      print('Failed to subscribe to $channelName: $e');
    }
  }

  Future<void> _unsubscribeFromChannel(String channelName) async {
    if (!_subscribedChannels.contains(channelName)) return;
    
    try {
      _socket!.emit('unsubscribe', {'channel': channelName});
      _subscribedChannels.remove(channelName);
      print('Requested unsubscription from channel: $channelName');
    } catch (e) {
      print('Failed to unsubscribe from $channelName: $e');
    }
  }

  List<String> _generateNearbyChannels(double latitude, double longitude, int radiusKm) {
    final channels = <String>[];
    const gridSize = 0.01; // ~1km grid
    final gridRadius = (radiusKm / 111).ceil(); // Approximate km per degree

    for (int latOffset = -gridRadius; latOffset <= gridRadius; latOffset++) {
      for (int lngOffset = -gridRadius; lngOffset <= gridRadius; lngOffset++) {
        final gridLat = ((latitude + (latOffset * gridSize)) * 100).round() / 100;
        final gridLng = ((longitude + (lngOffset * gridSize)) * 100).round() / 100;
        
        final channelName = 'alerts.location.${gridLat}_$gridLng';
        channels.add(channelName);
      }
    }

    final uniqueChannels = channels.toSet().toList(); // Remove duplicates
    
    // Limit to maximum 25 channels to prevent server overload
    if (uniqueChannels.length > 25) {
      print('⚠️ Generated ${uniqueChannels.length} channels, limiting to 25 for performance');
      return uniqueChannels.take(25).toList();
    }
    
    return uniqueChannels;
  }

  final Set<int> _processedAlertIds = {};
  static const int _maxProcessedAlerts = 1000; // Limit memory usage

  void _handleAlertCreated(dynamic data) {
    try {
      print('Processing alert.created: $data');
      
      if (data is Map<String, dynamic>) {
        final alertId = data['id'];
        
        // Prevent duplicate processing
        if (alertId != null && _processedAlertIds.contains(alertId)) {
          print('Alert $alertId already processed, skipping duplicate');
          return;
        }
        
        // Ensure description field is properly handled for null values
        final alertData = Map<String, dynamic>.from(data);
        if (alertData['description'] == null) {
          alertData['description'] = null; // Explicitly set to null for nullable field
        }
        
        // The Socket.IO server sends the alert data directly
        final alert = Alert.fromJson(alertData);
        _alertCreatedController.add(alert);
        
        // Mark as processed with memory limit
        if (alertId != null) {
          _processedAlertIds.add(alertId);
          
          // Clean up old processed alerts to prevent memory leaks
          if (_processedAlertIds.length > _maxProcessedAlerts) {
            final toRemove = _processedAlertIds.take(_processedAlertIds.length - _maxProcessedAlerts);
            _processedAlertIds.removeAll(toRemove);
            print('🧹 Cleaned up ${toRemove.length} old processed alert IDs');
          }
        }
      }
    } catch (e) {
      print('Error handling alert.created: $e');
      print('Failed alert data: $data');
    }
  }

  void _handleAlertConfirmed(dynamic data) {
    try {
      print('Processing alert.confirmed: $data');
      
      if (data is Map<String, dynamic>) {
        _alertConfirmedController.add(Map<String, dynamic>.from(data));
      }
    } catch (e) {
      print('Error handling alert.confirmed: $e');
    }
  }

  void _handleAlertDismissed(dynamic data) {
    try {
      print('Processing alert.dismissed: $data');
      
      if (data is Map<String, dynamic>) {
        _alertDismissedController.add(Map<String, dynamic>.from(data));
      }
    } catch (e) {
      print('Error handling alert.dismissed: $e');
    }
  }

  // Send events to Socket.IO server
  void reportAlert(String type, double latitude, double longitude, {String? description, int severity = 1}) {
    if (!_isConnected) {
      print('Cannot report alert: not connected to Socket.IO server');
      return;
    }
    
    _socket!.emit('report_alert', {
      'type': type,
      'latitude': latitude,
      'longitude': longitude,
      'description': description,
      'severity': severity,
    });
  }

  void confirmAlert(String alertId, String confirmationType, {String? comment}) {
    if (!_isConnected) {
      print('Cannot confirm alert: not connected to Socket.IO server');
      return;
    }
    
    _socket!.emit('confirm_alert', {
      'alert_id': alertId,
      'confirmation_type': confirmationType,
      'comment': comment,
    });
  }

  void updateUserLocation(double latitude, double longitude, {double? heading, double? speed}) {
    if (!_isConnected) return;
    
    _socket!.emit('location_update', {
      'latitude': latitude,
      'longitude': longitude,
      'heading': heading,
      'speed': speed,
      'timestamp': DateTime.now().toIso8601String(),
    });
    
    print('Sent location update: $latitude, $longitude');
  }

  // Connection management
  Future<void> reconnect() async {
    if (_socket != null) {
      _socket!.disconnect();
      _subscribedChannels.clear();
    }
    await _connect();
  }

  Future<void> disconnect() async {
    if (_socket != null) {
      _socket!.disconnect();
      _socket = null;
    }
    _isConnected = false;
    _subscribedChannels.clear();
    
    // Only add to controller if it's not closed
    if (!_connectionStatusController.isClosed) {
      _connectionStatusController.add(false);
    }
  }

  // Getters
  bool get isConnected => _isConnected;
  List<String> get subscribedChannels => List.from(_subscribedChannels);

  // Clean up
  void dispose() {
    print('🧹 Disposing WebSocket service...');
    disconnect();
    
    // Clear memory caches
    _processedAlertIds.clear();
    _subscribedChannels.clear();
    
    // Close streams safely
    if (!_alertCreatedController.isClosed) {
      _alertCreatedController.close();
    }
    if (!_alertConfirmedController.isClosed) {
      _alertConfirmedController.close();
    }
    if (!_alertDismissedController.isClosed) {
      _alertDismissedController.close();
    }
    if (!_connectionStatusController.isClosed) {
      _connectionStatusController.close();
    }
    
    print('✅ WebSocket service disposed');
  }
}