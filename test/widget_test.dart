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

    // Initial pump should render AuthGate
    expect(find.byType(SmartAttendanceApp), findsOneWidget);
  });
}
