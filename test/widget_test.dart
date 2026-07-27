import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/main.dart';

void main() {
  testWidgets('App launches and shows the Chess title', (tester) async {
    await tester.pumpWidget(const ChessApp());

    expect(find.text('Chess'), findsWidgets);
    expect(find.text('White to move'), findsOneWidget);
  });
}
