import 'package:flutter_test/flutter_test.dart';
import 'package:lawyer_app/main.dart';

void main() {
  testWidgets('Landing shows branding', (WidgetTester tester) async {
    await tester.pumpWidget(const LawyerApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('ابدأ الآن'), findsOneWidget);
  });
}
