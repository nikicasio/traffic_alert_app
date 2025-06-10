import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/real_api_service.dart';

class MyReportsScreen extends StatefulWidget {
  @override
  _MyReportsScreenState createState() => _MyReportsScreenState();
}

class _MyReportsScreenState extends State<MyReportsScreen> {
  final RealApiService _apiService = RealApiService();
  List<Map<String, dynamic>> _reports = [];
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = null;
    });

    try {
      final reports = await _apiService.getUserReports();
      setState(() {
        _reports = reports;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteAlert(int alertId, int index) async {
    // Show confirmation dialog
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF374151),
          title: const Text(
            'Delete Report',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'Are you sure you want to delete this report? This action cannot be undone.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white70),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text(
                'Delete',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      try {
        // Show loading indicator
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(color: Colors.red),
          ),
        );

        final success = await _apiService.deleteAlert(alertId);
        
        // Close loading dialog
        Navigator.of(context).pop();

        if (success) {
          setState(() {
            _reports.removeAt(index);
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Report deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to delete report'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        // Close loading dialog if still open
        Navigator.of(context).pop();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _getAlertIcon(String type) {
    switch (type) {
      case 'accident':
        return '🚗';
      case 'fire':
        return '🔥';
      case 'police':
        return '🚔';
      case 'blocked_road':
        return '🚧';
      case 'traffic':
        return '🚦';
      case 'roadwork':
        return '🏗️';
      case 'obstacle':
        return '⚠️';
      default:
        return '📍';
    }
  }

  String _getAlertTypeDisplayName(String type) {
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
        return type.replaceAll('_', ' ').split(' ').map((word) => 
          word[0].toUpperCase() + word.substring(1)).join(' ');
    }
  }

  String _formatCoordinates(double? lat, double? lng) {
    if (lat == null || lng == null) return 'Unknown location';
    return '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('MMM dd, yyyy \'at\' HH:mm').format(date);
    } catch (e) {
      return dateString;
    }
  }

  Color _getStatusColor(bool isActive) {
    return isActive ? Colors.green : Colors.grey;
  }

  String _getStatusText(bool isActive) {
    return isActive ? 'Active' : 'Inactive';
  }

  // Helper methods for safe type parsing
  double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      try {
        return double.parse(value);
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) {
      try {
        return int.parse(value);
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  bool? _parseBool(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value;
    if (value is int) return value != 0;
    if (value is String) {
      final lower = value.toLowerCase();
      if (lower == 'true' || lower == '1') return true;
      if (lower == 'false' || lower == '0') return false;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111827),
      appBar: AppBar(
        title: const Text(
          'My Reports',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF1F2937),
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            // Navigate back to home screen specifically
            Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadReports,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.red),
            )
          : _hasError
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.red,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Failed to load reports',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _errorMessage ?? 'Unknown error occurred',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: _loadReports,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                          ),
                          child: const Text(
                            'Retry',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : _reports.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.report_outlined,
                              size: 64,
                              color: Colors.white70,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'No reports yet',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Your submitted alerts will appear here',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadReports,
                      color: Colors.red,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _reports.length,
                        itemBuilder: (context, index) {
                          final report = _reports[index];
                          final alertId = report['id'] is int ? report['id'] as int : int.parse(report['id'].toString());
                          final type = report['type'] as String;
                          final latitude = _parseDouble(report['latitude']);
                          final longitude = _parseDouble(report['longitude']);
                          final severity = _parseInt(report['severity']);
                          final description = report['description'] as String?;
                          final confirmedCount = _parseInt(report['confirmed_count']) ?? 0;
                          final dismissedCount = _parseInt(report['dismissed_count']) ?? 0;
                          final isActive = _parseBool(report['is_active']) ?? false;
                          final reportedAt = report['reported_at'] as String;

                          return Card(
                            color: const Color(0xFF1F2937),
                            margin: const EdgeInsets.only(bottom: 12),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        _getAlertIcon(type),
                                        style: const TextStyle(fontSize: 24),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _getAlertTypeDisplayName(type),
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            Text(
                                              _formatDate(reportedAt),
                                              style: const TextStyle(
                                                color: Colors.white70,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _getStatusColor(isActive),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          _getStatusText(isActive),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          color: Colors.red,
                                          size: 20,
                                        ),
                                        onPressed: () => _deleteAlert(alertId, index),
                                      ),
                                    ],
                                  ),
                                  
                                  const SizedBox(height: 12),
                                  
                                  // Location
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.location_on,
                                        color: Colors.white70,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          _formatCoordinates(latitude, longitude),
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  
                                  // Description if available
                                  if (description != null && description.isNotEmpty) ...[ 
                                    const SizedBox(height: 8),
                                    Text(
                                      description,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                  
                                  const SizedBox(height: 12),
                                  
                                  // Stats
                                  Row(
                                    children: [
                                      if (severity != null) ...[
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.orange,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            'Level $severity',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                      ],
                                      
                                      // Confirmations
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.thumb_up,
                                            color: Colors.green,
                                            size: 14,
                                          ),
                                          const SizedBox(width: 2),
                                          Text(
                                            confirmedCount.toString(),
                                            style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                      
                                      const SizedBox(width: 12),
                                      
                                      // Dismissals
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.thumb_down,
                                            color: Colors.red,
                                            size: 14,
                                          ),
                                          const SizedBox(width: 2),
                                          Text(
                                            dismissedCount.toString(),
                                            style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}