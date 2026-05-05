import 'package:flutter_test/flutter_test.dart';
import 'package:paczone/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const PacZoneApp());
    await tester.pump();
    expect(find.byType(PacZoneApp), findsOneWidget);
  });
}
