import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:colow_flutter/app.dart';

void main() {
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ColowApp());
    expect(find.text('COLOW'), findsOneWidget);
  });
}
