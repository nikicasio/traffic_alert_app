import 'package:flutter/material.dart';
import '../models/alert.dart';

class AlertMarker extends StatelessWidget {
  final Alert alert;
  
  const AlertMarker({Key? key, required this.alert}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    IconData iconData;
    Color iconColor;
    
    // Set icon based on alert type
    switch (alert.type) {
      case 'accident':
        iconData = Icons.car_crash;
        iconColor = Colors.red;
        break;
      case 'fire':
        iconData = Icons.local_fire_department;
        iconColor = Colors.orange;
        break;
      case 'police':
        iconData = Icons.local_police;
        iconColor = Colors.blue;
        break;
      case 'blocked_road':
        iconData = Icons.block;
        iconColor = Colors.black;
        break;
      case 'traffic':
        iconData = Icons.traffic;
        iconColor = Colors.yellow.shade700;
        break;
      default:
        iconData = Icons.warning;
        iconColor = Colors.grey;
    }
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: EdgeInsets.all(4),
      child: Icon(
        iconData,
        color: iconColor,
        size: 24,
      ),
    );
  }
}