import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/alert.dart';
import '../widgets/alert_card.dart';
import '../services/mock_data_service.dart';
import 'dart:math' as math;

class MeterView extends StatefulWidget {
  final double currentSpeed;
  final Alert? nextAlert;
  final List<Alert> alerts;
  final Set<int> confirmedReports;
  final Function(Alert) onConfirmAlert;
  final double currentLatitude;
  final double currentLongitude;

  const MeterView({
    Key? key,
    required this.currentSpeed,
    required this.nextAlert,
    required this.alerts,
    required this.confirmedReports,
    required this.onConfirmAlert,
    required this.currentLatitude,
    required this.currentLongitude,
  }) : super(key: key);

  @override
  State<MeterView> createState() => _MeterViewState();
}

class _MeterViewState extends State<MeterView>
    with TickerProviderStateMixin {
  late AnimationController _speedAnimationController;
  late AnimationController _progressAnimationController;
  late AnimationController _alertCardAnimationController;
  late AnimationController _drawerAnimationController;
  
  late Animation<double> _speedAnimation;
  late Animation<double> _progressAnimation;
  late Animation<Offset> _alertCardSlideAnimation;
  late Animation<double> _alertCardFadeAnimation;
  late Animation<double> _drawerSlideAnimation;
  
  double _previousSpeed = 0;
  Alert? _previousAlert;
  bool _isDrawerExpanded = false;

  @override
  void initState() {
    super.initState();
    
    // Initialize animation controllers
    _speedAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _progressAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    
    _alertCardAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _drawerAnimationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    
    // Initialize animations
    _speedAnimation = Tween<double>(
      begin: 0,
      end: widget.currentSpeed,
    ).animate(CurvedAnimation(
      parent: _speedAnimationController,
      curve: Curves.easeOutCubic,
    ));
    
    _progressAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(
      parent: _progressAnimationController,
      curve: Curves.easeInOutCubic,
    ));
    
    _alertCardSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _alertCardAnimationController,
      curve: Curves.easeOutBack,
    ));
    
    _alertCardFadeAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(
      parent: _alertCardAnimationController,
      curve: Curves.easeOut,
    ));
    
    _drawerSlideAnimation = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _drawerAnimationController,
      curve: Curves.easeOutCubic,
    ));
    
    // Start initial animations
    _speedAnimationController.forward();
    if (widget.nextAlert != null) {
      _alertCardAnimationController.forward();
      _progressAnimationController.forward();
    }
    
    _previousSpeed = widget.currentSpeed;
    _previousAlert = widget.nextAlert;
  }

  @override
  void didUpdateWidget(MeterView oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Animate speed changes
    if (widget.currentSpeed != _previousSpeed) {
      _speedAnimation = Tween<double>(
        begin: _previousSpeed,
        end: widget.currentSpeed,
      ).animate(CurvedAnimation(
        parent: _speedAnimationController,
        curve: Curves.easeOutCubic,
      ));
      _speedAnimationController.reset();
      _speedAnimationController.forward();
      _previousSpeed = widget.currentSpeed;
      
      // Add haptic feedback for significant speed changes
      if ((widget.currentSpeed - _previousSpeed).abs() > 5) {
        HapticFeedback.lightImpact();
      }
    }
    
    // Animate alert changes
    if (widget.nextAlert?.id != _previousAlert?.id) {
      if (widget.nextAlert != null) {
        _alertCardAnimationController.reset();
        _alertCardAnimationController.forward();
        _progressAnimationController.reset();
        _progressAnimationController.forward();
        
        // Haptic feedback for new alerts
        HapticFeedback.mediumImpact();
      } else {
        _alertCardAnimationController.reverse();
        _progressAnimationController.reverse();
      }
      _previousAlert = widget.nextAlert;
    }
  }

  @override
  void dispose() {
    _speedAnimationController.dispose();
    _progressAnimationController.dispose();
    _alertCardAnimationController.dispose();
    _drawerAnimationController.dispose();
    super.dispose();
  }

  void _toggleDrawer() {
    setState(() {
      _isDrawerExpanded = !_isDrawerExpanded;
    });
    
    if (_isDrawerExpanded) {
      _drawerAnimationController.forward();
    } else {
      _drawerAnimationController.reverse();
    }
    
    HapticFeedback.selectionClick();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        color: const Color(0xFF111827), // gray-900
        child: Column(
          children: [
            // Speed meter section
            Expanded(
              flex: 3,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: MediaQuery.of(context).size.height * 0.6,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 20),
                      
                      // Current speed display with animation
                      AnimatedBuilder(
                        animation: _speedAnimation,
                        builder: (context, child) {
                          return TweenAnimationBuilder<double>(
                            duration: const Duration(milliseconds: 800),
                            tween: Tween(begin: _previousSpeed * 3.6, end: widget.currentSpeed * 3.6),
                            curve: Curves.easeOutCubic,
                            builder: (context, animatedSpeed, child) {
                              return ShaderMask(
                                shaderCallback: (bounds) => LinearGradient(
                                  colors: _getSpeedGradientColors(animatedSpeed),
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ).createShader(bounds),
                                child: Text(
                                  '${animatedSpeed.round()}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 64,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'km/h',
                        style: TextStyle(
                          color: Color(0xFF9CA3AF), // gray-400
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // Progress bar section (only shows within 1km) with animation
                      if (widget.nextAlert != null && _getDistanceInKm(widget.nextAlert!) <= 1.0)
                        AnimatedBuilder(
                          animation: _progressAnimationController,
                          builder: (context, child) {
                            return SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0, 0.5),
                                end: Offset.zero,
                              ).animate(CurvedAnimation(
                                parent: _progressAnimationController,
                                curve: Curves.easeOutCubic,
                              )),
                              child: FadeTransition(
                                opacity: _progressAnimationController,
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: _buildProximityProgressBar(),
                                ),
                              ),
                            );
                          },
                        ),
                      
                      // Next alert card with slide animation
                      if (widget.nextAlert != null)
                        SlideTransition(
                          position: _alertCardSlideAnimation,
                          child: FadeTransition(
                            opacity: _alertCardFadeAnimation,
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 16),
                              constraints: const BoxConstraints(maxWidth: 400),
                              child: Hero(
                                tag: 'alert-${widget.nextAlert!.id}',
                                child: AlertCard(
                                  alert: widget.nextAlert!,
                                  isConfirmed: widget.confirmedReports.contains(widget.nextAlert!.id),
                                  onConfirm: () {
                                    HapticFeedback.heavyImpact();
                                    widget.onConfirmAlert(widget.nextAlert!);
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),
                      
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
            
            // Upcoming alerts section with slide animation
            Expanded(
              flex: 2,
              child: AnimatedBuilder(
                animation: _drawerSlideAnimation,
                builder: (context, child) {
                  return SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.3),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                      parent: _drawerAnimationController,
                      curve: Curves.easeOutCubic,
                    )),
                    child: _buildUpcomingAlertsSection(),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProximityProgressBar() {
    if (widget.nextAlert == null) return const SizedBox.shrink();
    
    final distanceKm = _getDistanceInKm(widget.nextAlert!);
    final isWithin1km = distanceKm <= 1.0;
    final progress = isWithin1km ? (1 - distanceKm) * 100 : 0;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      constraints: const BoxConstraints(maxWidth: 400),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          // Progress bar
          Container(
            height: 28,
            decoration: BoxDecoration(
              color: const Color(0xFF1F2937), // gray-800
              borderRadius: BorderRadius.circular(14),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Stack(
                children: [
                  // Progress fill with animation
                  Positioned.fill(
                    child: AnimatedBuilder(
                      animation: _progressAnimation,
                      builder: (context, child) {
                        return FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: (progress / 100) * _progressAnimation.value,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: _getProgressGradientColors(distanceKm),
                              ),
                            ),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1 + (0.1 * _progressAnimation.value)),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  
                  // Distance markers
                  Positioned.fill(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: const Text(
                            '1km',
                            style: TextStyle(
                              color: Color(0xFF6B7280), // gray-500
                              fontSize: 10,
                            ),
                          ),
                        ),
                        const Text(
                          '500m',
                          style: TextStyle(
                            color: Color(0xFF6B7280), // gray-500
                            fontSize: 10,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: const Text(
                            '0m',
                            style: TextStyle(
                              color: Color(0xFF6B7280), // gray-500
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          
          // Alert type indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: _getProgressColor(distanceKm),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: _getProgressColor(distanceKm).withOpacity(0.3),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Icon(
                  _getAlertIcon(widget.nextAlert!.type),
                  color: Colors.white,
                  size: 14,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  '${_getAlertLabel(widget.nextAlert!.type)} ahead',
                  style: const TextStyle(
                    color: Color(0xFF9CA3AF), // gray-400
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingAlertsSection() {
    final upcomingAlerts = widget.alerts.skip(1).take(3).toList();
    
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1F2937), // gray-800
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Pull indicator with tap to expand
          GestureDetector(
            onTap: _toggleDrawer,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.only(bottom: 12),
                    width: _isDrawerExpanded ? 60 : 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: _isDrawerExpanded 
                          ? const Color(0xFF9CA3AF) 
                          : const Color(0xFF6B7280), // gray-500
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _isDrawerExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 300),
                    child: Icon(
                      Icons.keyboard_arrow_up,
                      color: const Color(0xFF6B7280),
                      size: 16,
                    ),
                  ),
                ],
              ),
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
          
          // Upcoming alerts list with proper scrolling
          Flexible(
            child: upcomingAlerts.isEmpty
                ? Container(
                    padding: const EdgeInsets.all(32),
                    child: const Text(
                      'No upcoming alerts',
                      style: TextStyle(
                        color: Color(0xFF6B7280), // gray-500
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  )
                : AnimatedList(
                    shrinkWrap: true,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    initialItemCount: upcomingAlerts.length,
                    itemBuilder: (context, index, animation) {
                      if (index >= upcomingAlerts.length) return const SizedBox.shrink();
                      return SlideTransition(
                        position: animation.drive(
                          Tween<Offset>(
                            begin: const Offset(1, 0),
                            end: Offset.zero,
                          ).chain(CurveTween(curve: Curves.easeOutCubic)),
                        ),
                        child: FadeTransition(
                          opacity: animation,
                          child: _buildUpcomingAlertItem(upcomingAlerts[index], index),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingAlertItem(Alert alert, int index) {
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 300 + (index * 100)),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Transform.scale(
          scale: 0.8 + (0.2 * value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF374151), // gray-700
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1 * value),
                  blurRadius: 4 * value,
                  offset: Offset(0, 2 * value),
                ),
              ],
            ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Alert icon with pulse animation
            AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _getAlertColor(alert.type),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: _getAlertColor(alert.type).withOpacity(0.3),
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                ],
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
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _getAlertLabel(alert.type),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Road ahead', // Simplified location
                    style: const TextStyle(
                      color: Color(0xFF9CA3AF), // gray-400
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ],
              ),
            ),
            
            const SizedBox(width: 8),
            
            // Distance and confirmations
            Expanded(
              flex: 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${_getDistanceInKm(alert).toStringAsFixed(1)} km',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${alert.confirmedCount} confirms',
                    style: const TextStyle(
                      color: Color(0xFF9CA3AF), // gray-400
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
          ),
        );
      },
    );
  }

  double _getDistanceInKm(Alert alert) {
    final dataService = MockDataService();
    final distanceInMeters = dataService.getDistanceToAlert(alert, widget.currentLatitude, widget.currentLongitude);
    return distanceInMeters / 1000;
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

  List<Color> _getSpeedGradientColors(double speed) {
    if (speed <= 30) {
      return [const Color(0xFF10B981), const Color(0xFF059669)]; // green
    } else if (speed <= 60) {
      return [const Color(0xFFF59E0B), const Color(0xFFD97706)]; // yellow
    } else if (speed <= 100) {
      return [const Color(0xFFF97316), const Color(0xFFEA580C)]; // orange
    } else {
      return [const Color(0xFFEF4444), const Color(0xFFDC2626)]; // red
    }
  }
}