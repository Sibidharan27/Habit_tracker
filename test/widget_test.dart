import 'package:flutter_test/flutter_test.dart';
import 'package:mad_project/app.dart';

void main() {
  testWidgets('App loads successfully', (WidgetTester tester) async {

    await tester.pumpWidget(const MyApp());

    // Just check app builds without crashing
    expect(find.byType(MyApp), findsOneWidget);
  });
}