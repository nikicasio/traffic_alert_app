import 'package:flutter/material.dart';
import 'screens/radar_alert_screen.dart';

void main() {
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
      home: RadarAlertScreen(),
    );
  }
}