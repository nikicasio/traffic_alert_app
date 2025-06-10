import 'package:flutter/material.dart';
import 'screens/radar_alert_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/my_reports_screen.dart';
import 'services/real_api_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize API service (core functionality)
  final apiService = RealApiService();
  await apiService.initialize();
  
  runApp(TrafficAlertApp());
}

class TrafficAlertApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RadarAlert',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        scaffoldBackgroundColor: const Color(0xFF111827), // gray-900
      ),
      home: AuthCheckScreen(),
      routes: {
        '/auth': (context) => AuthScreen(),
        '/home': (context) => RadarAlertScreen(),
        '/my-reports': (context) => MyReportsScreen(),
      },
    );
  }
}

class AuthCheckScreen extends StatefulWidget {
  @override
  _AuthCheckScreenState createState() => _AuthCheckScreenState();
}

class _AuthCheckScreenState extends State<AuthCheckScreen> {
  final _apiService = RealApiService();
  bool _isChecking = true;

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    await Future.delayed(Duration(seconds: 1)); // Show splash for a moment
    
    if (_apiService.isAuthenticated) {
      Navigator.of(context).pushReplacementNamed('/home');
    } else {
      Navigator.of(context).pushReplacementNamed('/auth');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111827),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.traffic,
              size: 100,
              color: Colors.red,
            ),
            const SizedBox(height: 24),
            Text(
              'RadarAlert',
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 32),
            CircularProgressIndicator(
              color: Colors.red,
            ),
          ],
        ),
      ),
    );
  }
}