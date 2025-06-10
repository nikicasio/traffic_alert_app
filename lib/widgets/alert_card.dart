import 'package:flutter/material.dart';
import '../models/alert.dart';

class AlertCard extends StatefulWidget {
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
  _AlertCardState createState() => _AlertCardState();
}

class _AlertCardState extends State<AlertCard> with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
    
    if (_isExpanded) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggleExpanded,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1F2937),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _isExpanded ? Color(widget.alert.color) : Colors.transparent,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: _isExpanded 
                  ? Color(widget.alert.color).withOpacity(0.3)
                  : Colors.black.withOpacity(0.1),
              blurRadius: _isExpanded ? 12 : 4,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // Always visible header section
            Row(
              children: [
                // Alert icon with pulse animation for expanded state
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Color(widget.alert.color),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: _isExpanded ? [
                      BoxShadow(
                        color: Color(widget.alert.color).withOpacity(0.4),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ] : [],
                  ),
                  child: Icon(
                    _getAlertIcon(widget.alert.type),
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                
                const SizedBox(width: 16),
                
                // Alert info - always visible
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _getAlertLabel(widget.alert.type),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (_isFresh(widget.alert))
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.flash_on,
                                    color: Color(0xFF10B981),
                                    size: 14,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'Fresh',
                                    style: TextStyle(
                                      color: Color(0xFF10B981),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      // Distance - always visible
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on,
                            color: Color(0xFF9CA3AF),
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${_getDistanceInKm(widget.alert).toStringAsFixed(1)} km ahead',
                            style: const TextStyle(
                              color: Color(0xFF9CA3AF),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Expand/collapse indicator
                AnimatedRotation(
                  turns: _isExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 300),
                  child: Icon(
                    Icons.keyboard_arrow_down,
                    color: Color(widget.alert.color),
                    size: 28,
                  ),
                ),
              ],
            ),
            
            // Expandable content
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: Column(
                children: [
                  const SizedBox(height: 20),
                  
                  // Divider
                  Container(
                    height: 1,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          Color(widget.alert.color).withOpacity(0.3),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Detailed information
                  Row(
                    children: [
                      Expanded(
                        child: _buildInfoCard(
                          'Severity',
                          _getSeverityText(widget.alert.severity ?? 1),
                          Icons.warning_amber_rounded,
                          _getSeverityColor(widget.alert.severity ?? 1),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildInfoCard(
                          'Confirmations',
                          '${widget.alert.confirmedCount ?? 0}',
                          Icons.thumb_up,
                          const Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Description if available
                  if (widget.alert.description != null && widget.alert.description!.isNotEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF374151),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: Color(0xFF9CA3AF),
                                size: 16,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Description',
                                style: TextStyle(
                                  color: Color(0xFF9CA3AF),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.alert.description!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  
                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: widget.isConfirmed ? null : widget.onConfirm,
                          icon: Icon(
                            widget.isConfirmed ? Icons.check_circle : Icons.thumb_up,
                            size: 18,
                          ),
                          label: Text(
                            widget.isConfirmed ? 'Confirmed' : 'Confirm',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: widget.isConfirmed 
                                ? const Color(0xFF10B981)
                                : Color(widget.alert.color),
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: const Color(0xFF10B981),
                            disabledForegroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.red.withOpacity(0.3)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          onPressed: () {
                            // TODO: Implement dismiss functionality
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Alert dismissed'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          },
                          icon: const Icon(
                            Icons.close,
                            color: Colors.red,
                            size: 20,
                          ),
                          tooltip: 'Dismiss',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              crossFadeState: _isExpanded 
                  ? CrossFadeState.showSecond 
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 300),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF374151),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: color,
            size: 20,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF9CA3AF),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _getSeverityText(int severity) {
    switch (severity) {
      case 1:
        return 'Low';
      case 2:
        return 'Medium';
      case 3:
        return 'High';
      case 4:
        return 'Critical';
      case 5:
        return 'Emergency';
      default:
        return 'Unknown';
    }
  }

  Color _getSeverityColor(int severity) {
    switch (severity) {
      case 1:
        return const Color(0xFF10B981); // green
      case 2:
        return const Color(0xFFF59E0B); // yellow
      case 3:
        return const Color(0xFFEF4444); // red
      case 4:
        return const Color(0xFF8B5CF6); // purple
      case 5:
        return const Color(0xFFDC2626); // dark red
      default:
        return const Color(0xFF6B7280); // gray
    }
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
      case 'roadwork':
        return Icons.construction;
      case 'obstacle':
        return Icons.warning;
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
      case 'roadwork':
        return 'Roadwork';
      case 'obstacle':
        return 'Obstacle';
      default:
        return 'Alert';
    }
  }
}