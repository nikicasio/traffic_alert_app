import 'package:flutter/material.dart';
import '../models/alert.dart';
import '../widgets/alert_card.dart';
import 'dart:math' as math;

class MeterView extends StatelessWidget {
  final double currentSpeed;
  final Alert? nextAlert;
  final List<Alert> alerts;
  final Set<int> confirmedReports;
  final Function(Alert) onConfirmAlert;

  const MeterView({
    Key? key,
    required this.currentSpeed,
    required this.nextAlert,
    required this.alerts,
    required this.confirmedReports,
    required this.onConfirmAlert,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF111827), // gray-900
      child: Column(
        children: [
          // Speed meter section
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Current speed display
                Text(
                  '${(currentSpeed * 3.6).round()}', // Convert m/s to km/h
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 72,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'km/h',
                  style: TextStyle(
                    color: Color(0xFF9CA3AF), // gray-400
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 32),
                
                // Progress bar section (only shows within 1km)
                if (nextAlert != null && _getDistanceInKm(nextAlert!) <= 1.0)
                  _buildProximityProgressBar(),
                
                const SizedBox(height: 24),
                
                // Next alert card
                if (nextAlert != null)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: AlertCard(
                      alert: nextAlert!,
                      isConfirmed: confirmedReports.contains(nextAlert!.id),
                      onConfirm: () => onConfirmAlert(nextAlert!),
                    ),
                  ),
              ],
            ),
          ),
          
          // Upcoming alerts section
          _buildUpcomingAlertsSection(),
        ],
      ),
    );
  }

  Widget _buildProximityProgressBar() {
    if (nextAlert == null) return const SizedBox.shrink();
    
    final distanceKm = _getDistanceInKm(nextAlert!);
    final isWithin1km = distanceKm <= 1.0;
    final progress = isWithin1km ? (1 - distanceKm) * 100 : 0;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      constraints: const BoxConstraints(maxWidth: 400),
      child: Column(
        children: [
          // Distance info
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Distance',
                style: TextStyle(
                  color: Color(0xFF9CA3AF), // gray-400
                  fontSize: 14,
                ),
              ),
              Text(
                '${(distanceKm * 1000).round()}m',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          // Progress bar
          Container(
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFF1F2937), // gray-800
              borderRadius: BorderRadius.circular(16),
            ),
            child: Stack(
              children: [
                // Progress fill
                Positioned.fill(
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: progress / 100,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: _getProgressGradientColors(distanceKm),
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ),
                
                // Distance markers
                Positioned.fill(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: const Text(
                          '1km',
                          style: TextStyle(
                            color: Color(0xFF6B7280), // gray-500
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const Text(
                        '500m',
                        style: TextStyle(
                          color: Color(0xFF6B7280), // gray-500
                          fontSize: 12,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: const Text(
                          '0m',
                          style: TextStyle(
                            color: Color(0xFF6B7280), // gray-500
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          
          // Alert type indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: _getProgressColor(distanceKm),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getAlertIcon(nextAlert!.type),
                  color: Colors.white,
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${_getAlertLabel(nextAlert!.type)} ahead',
                style: const TextStyle(
                  color: Color(0xFF9CA3AF), // gray-400
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingAlertsSection() {
    final upcomingAlerts = alerts.skip(1).take(3).toList();
    
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1F2937), // gray-800
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          // Pull indicator
          Container(
            margin: const EdgeInsets.only(top: 16, bottom: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFF6B7280), // gray-500
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Section title
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.centerLeft,
            child: const Text(
              'Upcoming Alerts',
              style: TextStyle(
                color: Color(0xFF9CA3AF), // gray-400
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          
          // Upcoming alerts list
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: upcomingAlerts.map((alert) => _buildUpcomingAlertItem(alert)).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingAlertItem(Alert alert) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF374151), // gray-700
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          // Alert icon
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Color(alert.color),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _getAlertIcon(alert.type),
              color: Colors.white,
              size: 16,
            ),
          ),
          
          const SizedBox(width: 12),
          
          // Alert info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getAlertLabel(alert.type),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  'Road ahead', // Simplified location
                  style: const TextStyle(
                    color: Color(0xFF9CA3AF), // gray-400
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          
          // Distance and confirmations
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${_getDistanceInKm(alert).toStringAsFixed(1)} km',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '${alert.confirmedCount} confirms',
                style: const TextStyle(
                  color: Color(0xFF9CA3AF), // gray-400
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  double _getDistanceInKm(Alert alert) {
    // For now, return a mock distance
    // In real implementation, this would calculate based on current location
    return alert.distance != null ? alert.distance! / 1000 : 1.0;
  }

  Color _getProgressColor(double distanceKm) {
    if (distanceKm > 0.5) return const Color(0xFF10B981); // green-500
    if (distanceKm > 0.2) return const Color(0xFFF59E0B); // yellow-500
    if (distanceKm > 0.1) return const Color(0xFFF97316); // orange-500
    return const Color(0xFFEF4444); // red-500
  }

  List<Color> _getProgressGradientColors(double distanceKm) {
    if (distanceKm > 0.5) return [const Color(0xFF34D399), const Color(0xFF059669)]; // green-400 to green-600
    if (distanceKm > 0.2) return [const Color(0xFFFBBF24), const Color(0xFFD97706)]; // yellow-400 to yellow-600
    if (distanceKm > 0.1) return [const Color(0xFFFB923C), const Color(0xFFEA580C)]; // orange-400 to orange-600
    return [const Color(0xFFF87171), const Color(0xFFDC2626)]; // red-400 to red-600
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