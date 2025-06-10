import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;

class RoadNameBar extends StatefulWidget {
  final LatLng currentLocation;
  final bool isLocationReady;

  const RoadNameBar({
    Key? key,
    required this.currentLocation,
    required this.isLocationReady,
  }) : super(key: key);

  @override
  State<RoadNameBar> createState() => _RoadNameBarState();
}

class _RoadNameBarState extends State<RoadNameBar> {
  String _roadName = 'Determining location...';
  bool _isLoading = false;
  LatLng? _lastLocation;

  @override
  void initState() {
    super.initState();
    if (widget.isLocationReady) {
      _getRoadName();
    }
  }

  @override
  void didUpdateWidget(RoadNameBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Update road name when location changes significantly (>50 meters)
    if (widget.isLocationReady && 
        (_lastLocation == null || _calculateDistance(_lastLocation!, widget.currentLocation) > 50)) {
      _getRoadName();
    }
  }

  double _calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371000; // Earth's radius in meters
    
    double lat1Rad = point1.latitude * (pi / 180);
    double lat2Rad = point2.latitude * (pi / 180);
    double deltaLatRad = (point2.latitude - point1.latitude) * (pi / 180);
    double deltaLngRad = (point2.longitude - point1.longitude) * (pi / 180);

    double a = sin(deltaLatRad / 2) * sin(deltaLatRad / 2) +
        cos(lat1Rad) * cos(lat2Rad) *
        sin(deltaLngRad / 2) * sin(deltaLngRad / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  Future<void> _getRoadName() async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      // Using Nominatim reverse geocoding (free OpenStreetMap service)
      final response = await http.get(
        Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?'
          'format=json&'
          'lat=${widget.currentLocation.latitude}&'
          'lon=${widget.currentLocation.longitude}&'
          'zoom=18&'
          'addressdetails=1'
        ),
        headers: {
          'User-Agent': 'RadarAlert/1.0.0',
        },
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String roadName = 'Unknown road';

        if (data['address'] != null) {
          final address = data['address'];
          
          // Try different road name fields in order of preference
          roadName = address['road'] ?? 
                    address['street'] ?? 
                    address['pedestrian'] ?? 
                    address['highway'] ?? 
                    address['path'] ?? 
                    address['cycleway'] ?? 
                    'Unknown road';

          // Remove city context - only show road name
        }

        setState(() {
          _roadName = roadName;
          _lastLocation = widget.currentLocation;
        });
      }
    } catch (e) {
      print('Error getting road name: $e');
      setState(() {
        _roadName = 'Location unavailable';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isLocationReady) {
      return const SizedBox.shrink();
    }

    return Positioned(
      bottom: 76, // Position between recenter button and + button
      left: 72, // Position after recenter button
      right: 72, // Position before + button
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1F2937).withOpacity(0.8), // More transparent
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: const Color(0xFF374151).withOpacity(0.5), // gray-700 with transparency
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.location_on,
              color: const Color(0xFF10B981), // green-500
              size: 14,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: _isLoading
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 10,
                          height: 10,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white.withOpacity(0.7),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Getting...',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    )
                  : Text(
                      _roadName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}