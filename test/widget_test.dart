import 'package:flutter_test/flutter_test.dart';
import 'package:caresync_ai/main.dart';

void main() {
  testWidgets('CareSync app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const CareSyncApp());
    expect(find.byType(CareSyncApp), findsOneWidget);
  });
}
