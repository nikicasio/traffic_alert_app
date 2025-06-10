import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/alert.dart';
import 'dart:async';

class StillThereDialog extends StatefulWidget {
  final Alert alert;
  final Function(int, bool)? onConfirmation;
  final VoidCallback? onDismiss;

  const StillThereDialog({
    Key? key,
    required this.alert,
    this.onConfirmation,
    this.onDismiss,
  }) : super(key: key);

  @override
  State<StillThereDialog> createState() => _StillThereDialogState();
}

class _StillThereDialogState extends State<StillThereDialog>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _fadeController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  
  Timer? _autoCloseTimer;
  bool _isDismissing = false;

  @override
  void initState() {
    super.initState();

    // Initialize animation controllers
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    // Create animations
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutBack,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    ));

    // Start entrance animation
    _slideController.forward();
    _fadeController.forward();

    // Auto-dismiss after 7 seconds
    _autoCloseTimer = Timer(const Duration(seconds: 7), () {
      if (!_isDismissing) {
        _dismissDialog();
      }
    });
  }

  void _dismissDialog() {
    if (_isDismissing) return;
    
    setState(() {
      _isDismissing = true;
    });
    
    _autoCloseTimer?.cancel();
    
    // Exit animation
    _slideController.reverse().then((_) {
      if (widget.onDismiss != null) {
        widget.onDismiss!();
      }
    });
  }

  void _confirmAlert(bool isStillThere) {
    if (_isDismissing) return;
    
    setState(() {
      _isDismissing = true;
    });
    
    _autoCloseTimer?.cancel();
    HapticFeedback.lightImpact();
    
    if (widget.onConfirmation != null) {
      widget.onConfirmation!(widget.alert.id!, isStillThere);
    }
    
    _dismissDialog();
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
      case 'roadwork':
        return Icons.construction;
      case 'obstacle':
        return Icons.warning;
      default:
        return Icons.warning;
    }
  }

  Color _getAlertColor(String type) {
    switch (type) {
      case 'accident':
        return const Color(0xFFEF4444); // red-500
      case 'fire':
        return const Color(0xFFFF6600); // orange
      case 'police':
        return const Color(0xFF3B82F6); // blue-500
      case 'blocked_road':
        return const Color(0xFF6B7280); // gray-500
      case 'traffic':
        return const Color(0xFFF59E0B); // yellow-500
      case 'roadwork':
        return const Color(0xFFFF6600); // orange
      case 'obstacle':
        return const Color(0xFFF59E0B); // yellow-500
      default:
        return const Color(0xFF6B7280); // gray-500
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
        return 'Road Block';
      case 'traffic':
        return 'Traffic Jam';
      case 'roadwork':
        return 'Roadwork';
      case 'obstacle':
        return 'Obstacle';
      default:
        return 'Alert';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 120, // Position above bottom elements
      left: 16,
      right: 16,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: GestureDetector(
            // Swipe to dismiss
            onHorizontalDragEnd: (details) {
              if (details.primaryVelocity!.abs() > 500) {
                _dismissDialog();
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1F2937), // gray-800
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _getAlertColor(widget.alert.type),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header with close button
                  Row(
                    children: [
                      Icon(
                        _getAlertIcon(widget.alert.type),
                        color: _getAlertColor(widget.alert.type),
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Still there?',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Is the ${_getAlertLabel(widget.alert.type).toLowerCase()} still at this location?',
                              style: const TextStyle(
                                color: Color(0xFF9CA3AF), // gray-400
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Close button
                      GestureDetector(
                        onTap: _dismissDialog,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _confirmAlert(true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981), // green-500
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text(
                            'Yes',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _confirmAlert(false),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFEF4444), // red-500
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text(
                            'No',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Swipe hint
                  Text(
                    'Swipe left or right to dismiss',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _autoCloseTimer?.cancel();
    _slideController.dispose();
    _fadeController.dispose();
    super.dispose();
  }
}