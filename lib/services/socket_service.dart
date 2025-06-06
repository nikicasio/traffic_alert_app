import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'dart:async';
import '../models/alert.dart';

class SocketService {
  final String serverUrl;
  IO.Socket? _socket;
  
  final _newAlertController = StreamController<Alert>.broadcast();
  final _alertConfirmedController = StreamController<Map<String, dynamic>>.broadcast();
  final _alertDismissedController = StreamController<int>.broadcast();
  
  Stream<Alert> get onNewAlert => _newAlertController.stream;
  Stream<Map<String, dynamic>> get onAlertConfirmed => _alertConfirmedController.stream;
  Stream<int> get onAlertDismissed => _alertDismissedController.stream;
  
  bool _isConnected = false;
  bool get isConnected => _isConnected;
  
  SocketService({required this.serverUrl});
  
  void connect() {
    if (_socket != null) {
      _socket!.disconnect();
    }
    
    try {
      _socket = IO.io(serverUrl, <String, dynamic>{
        'transports': ['websocket'],
        'autoConnect': true,
      });
      
      _socket!.onConnect((_) {
        print('Socket connected');
        _isConnected = true;
      });
      
      _socket!.onDisconnect((_) {
        print('Socket disconnected');
        _isConnected = false;
      });
      
      _socket!.on('new-alert', (data) {
        print('New alert received: $data');
        final alert = Alert(
          id: data['id'],
          type: data['type'],
          latitude: data['latitude'],
          longitude: data['longitude'],
          reportedAt: DateTime.parse(data['reported_at'] ?? DateTime.now().toIso8601String()),
          confirmedCount: data['confirmed_count'] ?? 1,
          isActive: data['is_active'] ?? true,
        );
        _newAlertController.add(alert);
      });
      
      _socket!.on('alert-confirmed', (data) {
        print('Alert confirmed: $data');
        _alertConfirmedController.add({
          'id': data['id'],
          'confirmedCount': data['confirmed_count'],
        });
      });
      
      _socket!.on('alert-dismissed', (data) {
        print('Alert dismissed: $data');
        _alertDismissedController.add(data['id']);
      });
      
      _socket!.on('error', (error) {
        print('Socket error: $error');
      });
      
      _socket!.connect();
    } catch (e) {
      print('Error setting up socket: $e');
    }
  }
  
  void disconnect() {
    _socket?.disconnect();
    _isConnected = false;
  }
  
  void dispose() {
    disconnect();
    _newAlertController.close();
    _alertConfirmedController.close();
    _alertDismissedController.close();
  }
}