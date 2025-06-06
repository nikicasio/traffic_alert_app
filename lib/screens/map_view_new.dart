import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/alert.dart';
import '../widgets/alert_marker.dart';

class MapViewNew extends StatelessWidget {
  final LatLng currentLocation;
  final List<Alert> alerts;
  final double currentSpeed;
  final Alert? nextAlert;
  final bool isLocationReady;
  final bool isOnline;

  const MapViewNew({
    Key? key,
    required this.currentLocation,
    required this.alerts,
    required this.currentSpeed,
    required this.nextAlert,
    required this.isLocationReady,
    required this.isOnline,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF111827), // gray-900
      child: isLocationReady
          ? Stack(
              children: [
                // Map
                FlutterMap(
                  options: MapOptions(
                    center: currentLocation,
                    zoom: 15.0,
                    interactiveFlags: InteractiveFlag.all,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: isOnline
                          ? 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'
                          : 'http://192.168.0.50:3000/osm_tiles/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.traffic_alert_app',
                    ),
                    MarkerLayer(
                      markers: [
                        // Current location marker
                        Marker(
                          point: currentLocation,
                          width: 40,
                          height: 40,
                          builder: (context) => Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF3B82F6), // blue-500
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF3B82F6).withOpacity(0.3),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.navigation,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                        // Alert markers
                        ...alerts.map((alert) {
                          return Marker(
                            point: alert.location,
                            width: 40,
                            height: 40,
                            builder: (context) => Container(
                              decoration: BoxDecoration(
                                color: Color(alert.color),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Color(alert.color).withOpacity(0.3),
                                    blurRadius: 8,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.location_on,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                  ],
                ),
                
                // Speed overlay (top left)
                Positioned(
                  top: 16,
                  left: 16,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1F2937), // gray-800
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Text(
                          '${(currentSpeed * 3.6).round()}', // Convert m/s to km/h
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Text(
                          'km/h',
                          style: TextStyle(
                            color: Color(0xFF9CA3AF), // gray-400
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Next alert overlay (top right, spans most of top)
                if (nextAlert != null)
                  Positioned(
                    top: 16,
                    right: 16,
                    left: 96, // Leave space for speed overlay
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1F2937), // gray-800
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              // Alert icon
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Color(nextAlert!.color),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  _getAlertIcon(nextAlert!.type),
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              
                              const SizedBox(width: 12),
                              
                              // Alert info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${_getAlertLabel(nextAlert!.type)} • ${_getDistanceInKm(nextAlert!).toStringAsFixed(1)} km',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      '${nextAlert!.confirmedCount} confirmations',
                                      style: const TextStyle(
                                        color: Color(0xFF9CA3AF), // gray-400
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          
                          // Mini progress bar (only shows within 1km)
                          if (_getDistanceInKm(nextAlert!) <= 1.0) ...[
                            const SizedBox(height: 8),
                            _buildMiniProgressBar(nextAlert!),
                          ],
                        ],
                      ),
                    ),
                  ),
                
                // Online/Offline indicator
                Positioned(
                  top: 50,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isOnline ? const Color(0xFF10B981) : const Color(0xFFEF4444), // green-500 or red-500
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      isOnline ? 'Online' : 'Offline',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            )
          : const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
    );
  }

  Widget _buildMiniProgressBar(Alert alert) {
    final distanceKm = _getDistanceInKm(alert);
    final progress = (1 - distanceKm) * 100;
    
    return Column(
      children: [
        Container(
          height: 8,
          decoration: BoxDecoration(
            color: const Color(0xFF374151), // gray-700
            borderRadius: BorderRadius.circular(4),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: progress / 100,
            child: Container(
              decoration: BoxDecoration(
                color: _getProgressColor(distanceKm),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${(distanceKm * 1000).round()}m away',
          style: const TextStyle(
            color: Color(0xFF9CA3AF), // gray-400
            fontSize: 10,
          ),
          textAlign: TextAlign.center,
        ),
      ],
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