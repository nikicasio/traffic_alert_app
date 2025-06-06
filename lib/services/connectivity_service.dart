import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'dart:async';

class ConnectivityService {
  final InternetConnectionChecker _connectionChecker = InternetConnectionChecker();
  final StreamController<bool> _connectionStatusController = StreamController<bool>.broadcast();
  
  Stream<bool> get connectionStream => _connectionStatusController.stream;
  bool _isConnected = false;
  bool get isConnected => _isConnected;
  
  ConnectivityService() {
    // Listen to connectivity changes
    _connectionChecker.onStatusChange.listen((status) {
      _isConnected = status == InternetConnectionStatus.connected;
      _connectionStatusController.add(_isConnected);
    });
    
    // Check current status
    checkConnection();
  }
  
  Future<bool> checkConnection() async {
    _isConnected = await _connectionChecker.hasConnection;
    _connectionStatusController.add(_isConnected);
    return _isConnected;
  }
  
  void dispose() {
    _connectionStatusController.close();
  }
}