import 'package:flutter/material.dart';
import 'screens/map_screen.dart';

void main() {
  runApp(TrafficAlertApp());
}

class TrafficAlertApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Traffic Alert',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: MapScreen(),
    );
  }
}