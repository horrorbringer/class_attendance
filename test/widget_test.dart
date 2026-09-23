import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:class_attendance/main.dart';

void main() {
  testWidgets('SmartAttendanceApp root smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: SmartAttendanceApp(),
      ),
    );

    // Initial pump should render SmartAttendanceApp and SplashScreen
    expect(find.byType(SmartAttendanceApp), findsOneWidget);

    // Fast-forward animation timers to settle the splash sequence
    await tester.pump(const Duration(seconds: 2));
  });
}
