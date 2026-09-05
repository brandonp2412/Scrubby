import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scrubby/screens/history_page.dart';

void main() {
  testWidgets('history renders and switches metrics at desktop width', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: CleaningHistoryPage(initialMetric: HistoryMetric.travelled),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Cleaning history'), findsOneWidget);
    expect(find.text('5.76 km'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Cleaned'));
    await tester.pumpAndSettle();

    expect(find.text('314 m²'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
