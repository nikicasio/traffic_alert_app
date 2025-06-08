import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

class ReportModal extends StatefulWidget {
  final LatLng currentLocation;
  final VoidCallback onClose;
  final Function(String) onSubmitReport;

  const ReportModal({
    Key? key,
    required this.currentLocation,
    required this.onClose,
    required this.onSubmitReport,
  }) : super(key: key);

  @override
  _ReportModalState createState() => _ReportModalState();
}

class _ReportModalState extends State<ReportModal> {
  String? selectedReportType;
  String selectedDirection = 'my_direction'; // 'my_direction' or 'opposite'

  final List<ReportType> reportTypes = [
    ReportType(
      type: 'police',
      icon: Icons.local_police,
      label: 'Police',
      color: Color(0xFF3B82F6), // blue-500
    ),
    ReportType(
      type: 'roadwork',
      icon: Icons.construction,
      label: 'Roadwork',
      color: Color(0xFFF59E0B), // yellow-500
    ),
    ReportType(
      type: 'obstacle',
      icon: Icons.warning,
      label: 'Obstacle',
      color: Color(0xFFF97316), // orange-500
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withOpacity(0.75),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          width: double.infinity,
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
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: Color(0xFF374151), // gray-700
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Report Alert',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      onPressed: widget.onClose,
                      icon: const Icon(
                        Icons.close,
                        color: Color(0xFF9CA3AF), // gray-400
                      ),
                    ),
                  ],
                ),
              ),
              
              // Content
              Container(
                padding: const EdgeInsets.all(16),
                child: selectedReportType == null
                    ? _buildTypeSelection()
                    : _buildDirectionSelection(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeSelection() {
    return Column(
      children: [
        // Type selection grid
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1,
          ),
          itemCount: reportTypes.length,
          itemBuilder: (context, index) {
            final reportType = reportTypes[index];
            return GestureDetector(
              onTap: () {
                setState(() {
                  selectedReportType = reportType.type;
                });
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF374151), // gray-700
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: reportType.color,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        reportType.icon,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      reportType.label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildDirectionSelection() {
    final selectedType = reportTypes.firstWhere((type) => type.type == selectedReportType);
    
    return Column(
      children: [
        // Location detection
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF374151), // gray-700
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.location_on,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Location detected',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 8),
        
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: const Text(
            'Current road • Direction detected',
            style: TextStyle(
              color: Color(0xFF9CA3AF), // gray-400
              fontSize: 14,
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Direction selection
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    selectedDirection = 'my_direction';
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: selectedDirection == 'my_direction'
                        ? const Color(0xFF3B82F6) // blue-600
                        : const Color(0xFF374151), // gray-700
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'My direction',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    selectedDirection = 'opposite';
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: selectedDirection == 'opposite'
                        ? const Color(0xFF3B82F6) // blue-600
                        : const Color(0xFF374151), // gray-700
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Opposite',
                    style: TextStyle(
                      color: Color(0xFF9CA3AF), // gray-300
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 16),
        
        // Submit button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              widget.onSubmitReport(selectedReportType!);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981), // green-600
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
            child: const Text(
              'Submit Report',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        
        const SizedBox(height: 32),
      ],
    );
  }
}

class ReportType {
  final String type;
  final IconData icon;
  final String label;
  final Color color;

  ReportType({
    required this.type,
    required this.icon,
    required this.label,
    required this.color,
  });
}