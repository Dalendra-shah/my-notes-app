import 'package:flutter_test/flutter_test.dart';
import 'package:my_notes_app/main.dart';

void main() {
  testWidgets('My Notes application loads', (WidgetTester tester) async {
    await tester.pumpWidget(const MyNotesApp());

    expect(find.text('My Notes'), findsOneWidget);
  });
}
