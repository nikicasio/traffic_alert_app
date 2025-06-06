import 'package:flutter/material.dart';
import '../models/alert.dart';

class AlertCard extends StatelessWidget {
  final Alert alert;
  final bool isConfirmed;
  final VoidCallback onConfirm;

  const AlertCard({
    Key? key,
    required this.alert,
    required this.isConfirmed,
    required this.onConfirm,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2937), // gray-800
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // Header with icon and basic info
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  // Alert icon
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Color(alert.color),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _getAlertIcon(alert.type),
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  
                  const SizedBox(width: 12),
                  
                  // Alert type and distance
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getAlertLabel(alert.type),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${_getDistanceInKm(alert).toStringAsFixed(1)} km',
                        style: const TextStyle(
                          color: Color(0xFF9CA3AF), // gray-400
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              
              // Fresh indicator
              if (_isFresh(alert))
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.2), // green with opacity
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.flash_on,
                        color: Color(0xFF10B981), // green-500
                        size: 16,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Fresh',
                        style: TextStyle(
                          color: Color(0xFF10B981), // green-500
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Details section
          Column(
            children: [
              _buildDetailRow('Location', 'Road ahead'),
              const SizedBox(height: 8),
              _buildDetailRow('Speed limit', '80 km/h'), // Mock speed limit
              const SizedBox(height: 8),
              _buildDetailRow(
                'Confirmations',
                '${alert.confirmedCount}',
                trailing: const Icon(
                  Icons.people,
                  color: Color(0xFF9CA3AF),
                  size: 16,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Confirm button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isConfirmed ? null : onConfirm,
              style: ElevatedButton.styleFrom(
                backgroundColor: isConfirmed 
                    ? const Color(0xFF059669) // green-600
                    : const Color(0xFF374151), // gray-700
                disabledBackgroundColor: const Color(0xFF059669),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isConfirmed) ...[
                    const Icon(
                      Icons.thumb_up,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Confirmed',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ] else
                    const Text(
                      'Confirm Alert',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {Widget? trailing}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF9CA3AF), // gray-400
            fontSize: 14,
          ),
        ),
        Row(
          children: [
            if (trailing != null) ...[
              trailing,
              const SizedBox(width: 4),
            ],
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  double _getDistanceInKm(Alert alert) {
    // For now, return a mock distance
    // In real implementation, this would calculate based on current location
    return alert.distance != null ? alert.distance! / 1000 : 1.0;
  }

  bool _isFresh(Alert alert) {
    final now = DateTime.now();
    final difference = now.difference(alert.reportedAt);
    return difference.inMinutes < 30; // Consider fresh if reported within 30 minutes
  }

  IconData _getAlertIcon(String type) {
    switch (type) {
      case 'accident':
        return Icons.car_crash;
      case 'fire':
        return Icons.local_fire_department;
      case 'police':
        return Icons.local_police;
      case 'blocked_road':
        return Icons.block;
      case 'traffic':
        return Icons.traffic;
      default:
        return Icons.warning;
    }
  }

  String _getAlertLabel(String type) {
    switch (type) {
      case 'accident':
        return 'Accident';
      case 'fire':
        return 'Fire';
      case 'police':
        return 'Police';
      case 'blocked_road':
        return 'Blocked Road';
      case 'traffic':
        return 'Traffic';
      default:
        return 'Alert';
    }
  }
}