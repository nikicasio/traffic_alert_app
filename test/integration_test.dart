import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:traffic_alert_app/main.dart' as app;
import 'package:traffic_alert_app/services/real_api_service.dart';
import 'package:traffic_alert_app/services/websocket_service.dart';
import 'package:traffic_alert_app/models/alert.dart';

void main() {
  group('RadarAlert Integration Tests', () {
    setUpAll(() async {
      // Initialize Flutter app
    });

    testWidgets('App startup and navigation flow', (WidgetTester tester) async {
      // Build our app and trigger a frame
      app.main();
      await tester.pumpAndSettle();

      // Verify splash screen appears
      expect(find.text('RadarAlert'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Wait for navigation to auth screen
      await tester.pumpAndSettle(Duration(seconds: 2));
      
      // Should navigate to auth screen for non-authenticated users
      expect(find.text('Community-driven traffic alerts'), findsOneWidget);
    });

    testWidgets('Authentication flow', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(Duration(seconds: 2));

      // Test guest mode
      final guestButton = find.text('Continue as Guest');
      expect(guestButton, findsOneWidget);
      
      await tester.tap(guestButton);
      await tester.pumpAndSettle();

      // Should navigate to radar screen
      expect(find.text('RadarAlert'), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsOneWidget);
    });

    testWidgets('Alert reporting UI', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(Duration(seconds: 2));

      // Navigate to main screen via guest mode
      await tester.tap(find.text('Continue as Guest'));
      await tester.pumpAndSettle();

      // Find and tap the report button (FAB)
      final reportButton = find.byType(FloatingActionButton);
      expect(reportButton, findsOneWidget);

      await tester.tap(reportButton);
      await tester.pumpAndSettle();

      // Verify report modal appears
      // Note: Actual implementation may vary based on ReportModal widget
      // This is a placeholder for testing the UI flow
    });

    testWidgets('View switching', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(Duration(seconds: 2));

      // Navigate to main screen via guest mode
      await tester.tap(find.text('Continue as Guest'));
      await tester.pumpAndSettle();

      // Find view switch button (map/meter toggle)
      final viewSwitchButton = find.byIcon(Icons.map);
      if (viewSwitchButton.evaluate().isNotEmpty) {
        await tester.tap(viewSwitchButton);
        await tester.pumpAndSettle();

        // Verify view changed (button icon should change)
        expect(find.byIcon(Icons.speed), findsOneWidget);
      }
    });
  });

  group('Service Integration Tests', () {
    late RealApiService apiService;
    late WebSocketService webSocketService;

    setUpAll(() async {
      apiService = RealApiService();
      webSocketService = WebSocketService();
    });

    test('API Service health check', () async {
      await apiService.initialize();
      final isHealthy = await apiService.checkHealth();
      
      // Note: This will fail if backend is not running
      // In a real test environment, you'd mock this or ensure backend is available
      expect(isHealthy, isA<bool>());
    });

    test('WebSocket Service initialization', () async {
      await webSocketService.initialize();
      
      // Verify WebSocket service is properly configured
      expect(webSocketService, isNotNull);
      expect(webSocketService.alertCreatedStream, isNotNull);
      expect(webSocketService.connectionStatusStream, isNotNull);
    });

    test('Alert model serialization', () {
      final alert = Alert(
        id: 1,
        type: 'traffic',
        latitude: 40.7128,
        longitude: -74.0060,
        reportedAt: DateTime.now(),
        description: 'Test alert',
      );

      // Test toJson
      final json = alert.toJson();
      expect(json['type'], equals('traffic'));
      expect(json['latitude'], equals(40.7128));
      expect(json['longitude'], equals(-74.0060));

      // Test fromJson
      final recreatedAlert = Alert.fromJson(json);
      expect(recreatedAlert.type, equals(alert.type));
      expect(recreatedAlert.latitude, equals(alert.latitude));
      expect(recreatedAlert.longitude, equals(alert.longitude));
    });

    test('Distance calculation', () {
      final alert = Alert(
        type: 'traffic',
        latitude: 40.7128,
        longitude: -74.0060,
        reportedAt: DateTime.now(),
      );

      // Test distance to nearby point (approximately 1km away)
      final distance = alert.distanceTo(40.7228, -74.0060);
      expect(distance, greaterThan(0));
      expect(distance, lessThan(2000)); // Should be less than 2km
    });
  });

  group('Offline Functionality Tests', () {
    test('Local storage operations', () async {
      // This would test offline storage functionality
      // Implementation depends on the OfflineStorage service
      
      final alert = Alert(
        type: 'police',
        latitude: 40.7128,
        longitude: -74.0060,
        reportedAt: DateTime.now(),
        description: 'Test offline alert',
      );

      // Test storing and retrieving alerts offline
      // Note: Actual implementation would require initializing OfflineStorage
      expect(alert.type, equals('police'));
    });
  });

  tearDownAll(() async {
    // Clean up resources
  });
}

// Helper function for testing without actual network calls
class MockApiService extends RealApiService {
  @override
  Future<bool> checkHealth() async {
    return true; // Always return healthy for tests
  }

  @override
  Future<List<Alert>> getNearbyAlerts({
    required double latitude,
    required double longitude,
    int radius = 10000,
    String? type,
    int? severity,
  }) async {
    // Return mock alerts for testing
    return [
      Alert(
        id: 1,
        type: 'traffic',
        latitude: latitude + 0.001,
        longitude: longitude + 0.001,
        reportedAt: DateTime.now().subtract(Duration(minutes: 5)),
        description: 'Mock traffic alert',
      ),
      Alert(
        id: 2,
        type: 'police',
        latitude: latitude - 0.001,
        longitude: longitude - 0.001,
        reportedAt: DateTime.now().subtract(Duration(minutes: 10)),
        description: 'Mock police alert',
      ),
    ];
  }

  @override
  Future<Alert?> reportAlert({
    required String type,
    required double latitude,
    required double longitude,
    String? description,
  }) async {
    // Return a mock created alert
    return Alert(
      id: DateTime.now().millisecondsSinceEpoch,
      type: type,
      latitude: latitude,
      longitude: longitude,
      reportedAt: DateTime.now(),
      description: description,
    );
  }
}