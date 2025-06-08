import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/alert.dart';
import '../widgets/alert_marker.dart';
import '../services/mock_data_service.dart';
import 'dart:math';

class MapViewNew extends StatefulWidget {
  final LatLng currentLocation;
  final List<Alert> alerts;
  final double currentSpeed;
  final Alert? nextAlert;
  final bool isLocationReady;
  final bool isOnline;
  final double currentHeading;
  final Function(int, bool)? onAlertConfirmation; // callback for "still there?" responses

  const MapViewNew({
    Key? key,
    required this.currentLocation,
    required this.alerts,
    required this.currentSpeed,
    required this.nextAlert,
    required this.isLocationReady,
    required this.isOnline,
    required this.currentHeading,
    this.onAlertConfirmation,
  }) : super(key: key);

  @override
  State<MapViewNew> createState() => _MapViewNewState();
}

class _MapViewNewState extends State<MapViewNew> 
    with TickerProviderStateMixin {
  late MapController _mapController;
  late AnimationController _rotationController;
  late Animation<double> _rotationAnimation;
  
  bool _isFollowingUser = true;
  bool _is3DMode = false;
  double _previousHeading = 0;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    
    _rotationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    
    _rotationAnimation = Tween<double>(
      begin: 0,
      end: 0,
    ).animate(CurvedAnimation(
      parent: _rotationController,
      curve: Curves.easeOutCubic,
    ));
    
    _previousHeading = widget.currentHeading;
  }

  @override
  void didUpdateWidget(MapViewNew oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Auto-recenter if following user
    if (_isFollowingUser && widget.isLocationReady) {
      _centerOnUser();
    }
    
    // Smooth heading animation
    if (widget.currentHeading != _previousHeading) {
      _animateHeading();
    }
  }

  void _centerOnUser() {
    if (!widget.isLocationReady) return;
    
    _mapController.move(widget.currentLocation, _mapController.zoom);
    setState(() {
      _isFollowingUser = true;
    });
  }

  void _animateHeading() {
    _rotationAnimation = Tween<double>(
      begin: _previousHeading,
      end: widget.currentHeading,
    ).animate(CurvedAnimation(
      parent: _rotationController,
      curve: Curves.easeOutCubic,
    ));
    
    _rotationController.reset();
    _rotationController.forward();
    _previousHeading = widget.currentHeading;
  }

  void _onMapEvent(MapEvent event) {
    // Detect when user manually moves the map
    if (event is MapEventMove) {
      setState(() {
        _isFollowingUser = false;
      });
    }
  }

  void _toggleMapMode() {
    setState(() {
      _is3DMode = !_is3DMode;
    });
  }

  Widget _buildConfirmationPrompt() {
    // Check if there are any passed alerts that need confirmation
    // This would be connected to the data service's passed alerts
    // For now, we'll show a sample prompt when next alert is very close
    
    if (widget.nextAlert != null) {
      final distance = _getDistanceInKm(widget.nextAlert!);
      final shouldShowPrompt = distance <= 0.02; // Within 20 meters
      
      if (shouldShowPrompt) {
        return Positioned(
          top: 80,
          left: 16,
          right: 16,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1F2937), // gray-800
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFF59E0B), width: 2), // yellow border
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      _getAlertIcon(widget.nextAlert!.type),
                      color: _getAlertColor(widget.nextAlert!.type),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Still there?',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Is the ${_getAlertLabel(widget.nextAlert!.type).toLowerCase()} still at this location?',
                  style: const TextStyle(
                    color: Color(0xFF9CA3AF), // gray-400
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          widget.onAlertConfirmation?.call(widget.nextAlert!.id!, true);
                          HapticFeedback.lightImpact();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981), // green-500
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Yes', style: TextStyle(fontSize: 14)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          widget.onAlertConfirmation?.call(widget.nextAlert!.id!, false);
                          HapticFeedback.lightImpact();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEF4444), // red-500
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('No', style: TextStyle(fontSize: 14)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }
    }
    
    return const SizedBox.shrink();
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF111827), // gray-900
      child: widget.isLocationReady
          ? Stack(
              children: [
                // Map with smooth navigation
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    center: widget.currentLocation,
                    zoom: 16.0,
                    minZoom: 10.0,
                    maxZoom: 19.0,
                    onMapEvent: _onMapEvent,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: _is3DMode 
                          ? 'https://mt1.google.com/vt/lyrs=y&x={x}&y={y}&z={z}' // 3D satellite
                          : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', // 2D standard
                      userAgentPackageName: 'com.example.traffic_alert_app',
                      additionalOptions: _is3DMode ? {
                        'key': 'YOUR_GOOGLE_MAPS_API_KEY' // Add your API key for production
                      } : {},
                    ),
                    MarkerLayer(
                      markers: [
                        // Current location marker with smooth rotation
                        Marker(
                          point: widget.currentLocation,
                          width: 40,
                          height: 40,
                          builder: (context) => AnimatedBuilder(
                            animation: _rotationAnimation,
                            builder: (context, child) {
                              return Transform.rotate(
                                angle: (_rotationAnimation.value * pi) / 180,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF3B82F6), // blue-500
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF3B82F6).withOpacity(0.4),
                                        blurRadius: 12,
                                        spreadRadius: 3,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.navigation,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        // Alert markers with distance-based visibility
                        ...widget.alerts.map((alert) {
                          final distance = _getDistanceInKm(alert);
                          final opacity = distance <= 0.5 ? 1.0 : (1.0 - (distance - 0.5) / 0.5).clamp(0.3, 1.0);
                          
                          return Marker(
                            point: LatLng(alert.latitude, alert.longitude),
                            width: 40,
                            height: 40,
                            builder: (context) => AnimatedOpacity(
                              opacity: opacity,
                              duration: const Duration(milliseconds: 300),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: _getAlertColor(alert.type),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: _getAlertColor(alert.type).withOpacity(0.3 * opacity),
                                      blurRadius: 8,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  _getAlertIcon(alert.type),
                                  color: Colors.white,
                                  size: 20,
                                ),
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
                        TweenAnimationBuilder<double>(
                          duration: const Duration(milliseconds: 500),
                          tween: Tween(begin: 0, end: widget.currentSpeed * 3.6),
                          builder: (context, speed, child) {
                            return Text(
                              '${speed.round()}',
                              style: TextStyle(
                                color: _getSpeedColor(speed),
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                              ),
                            );
                          },
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
                
                // Recenter button (bottom left)
                Positioned(
                  bottom: 16,
                  left: 16,
                  child: Column(
                    children: [
                      // 2D/3D toggle button
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: _is3DMode ? const Color(0xFF3B82F6) : const Color(0xFF374151),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: IconButton(
                          onPressed: _toggleMapMode,
                          icon: Icon(
                            _is3DMode ? Icons.threed_rotation : Icons.map,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                      
                      // Recenter button
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          color: _isFollowingUser ? const Color(0xFF10B981) : const Color(0xFF374151),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: IconButton(
                          onPressed: _centerOnUser,
                          icon: Icon(
                            _isFollowingUser ? Icons.my_location : Icons.location_searching,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Next alert overlay (top right, spans most of top)
                if (widget.nextAlert != null)
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
                                  color: _getAlertColor(widget.nextAlert!.type),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  _getAlertIcon(widget.nextAlert!.type),
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
                                      '${_getAlertLabel(widget.nextAlert!.type)} • ${_getDistanceInKm(widget.nextAlert!).toStringAsFixed(1)} km',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      '${widget.nextAlert!.confirmedCount} confirmations',
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
                          if (_getDistanceInKm(widget.nextAlert!) <= 1.0) ...[
                            const SizedBox(height: 8),
                            _buildMiniProgressBar(widget.nextAlert!),
                          ],
                        ],
                      ),
                    ),
                  ),
                
                // Confirmation prompt for passed alerts
                _buildConfirmationPrompt(),
                
                // Online/Offline indicator
                Positioned(
                  top: 120, // Moved down to make space for confirmation prompt
                  right: 16,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: widget.isOnline ? const Color(0xFF10B981) : const Color(0xFFEF4444), // green-500 or red-500
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          widget.isOnline ? Icons.wifi : Icons.wifi_off,
                          color: Colors.white,
                          size: 12,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          widget.isOnline ? 'Online' : 'Offline',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
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
    final dataService = MockDataService();
    final distanceInMeters = dataService.getDistanceToAlert(alert, widget.currentLocation.latitude, widget.currentLocation.longitude);
    return distanceInMeters / 1000;
  }
  
  Color _getSpeedColor(double speed) {
    if (speed <= 30) return const Color(0xFF10B981); // green
    if (speed <= 60) return const Color(0xFFF59E0B); // yellow
    if (speed <= 100) return const Color(0xFFF97316); // orange
    return const Color(0xFFEF4444); // red
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
      case 'roadwork':
        return Icons.construction;
      case 'obstacle':
        return Icons.warning;
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
      case 'roadwork':
        return 'Roadwork';
      case 'obstacle':
        return 'Obstacle';
      case 'blocked_road':
        return 'Blocked Road';
      case 'traffic':
        return 'Traffic';
      default:
        return 'Alert';
    }
  }

  Color _getAlertColor(String type) {
    switch (type) {
      case 'police':
        return const Color(0xFF3B82F6); // blue-500
      case 'roadwork':
        return const Color(0xFFF59E0B); // yellow-500
      case 'obstacle':
        return const Color(0xFFF97316); // orange-500
      case 'accident':
        return const Color(0xFFEF4444); // red-500
      case 'fire':
        return const Color(0xFFDC2626); // red-600
      case 'traffic':
        return const Color(0xFF8B5CF6); // purple-500
      default:
        return const Color(0xFF6B7280); // gray-500
    }
  }
}