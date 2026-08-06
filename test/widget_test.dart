// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

import 'package:scrubby/main.dart';
import 'package:scrubby/core/home_assistant.dart';

void main() {
  testWidgets('shows Home Assistant connection screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ScrubbyApp());
    expect(find.text('Connect your home'), findsOneWidget);
    expect(find.text('Explore with demo home'), findsOneWidget);
  });

  testWidgets('demo home opens the vacuum dashboard', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const ScrubbyApp());
    await tester.tap(find.text('Explore with demo home'));
    await tester.pumpAndSettle();

    expect(find.text('Orbit'), findsWidgets);
    expect(find.text('START'), findsOneWidget);
    expect(find.text('Today at a glance'), findsOneWidget);
  });

  test('reads battery values without inventing zero for missing data', () {
    VacuumEntity entityWith(Map<String, Object?> attributes) =>
        VacuumEntity.fromJson({
          'entity_id': 'vacuum.test',
          'state': 'docked',
          'attributes': attributes,
        });

    expect(entityWith({'battery_percentage': '72%'}).battery, 72);
    expect(entityWith({'battery': 54.6}).battery, 55);
    expect(entityWith({}).battery, isNull);
  });

  testWidgets('mobile dashboard controls open and labels stay on one line', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const ScrubbyApp());
    await tester.tap(find.text('Explore with demo home'));
    await tester.pumpAndSettle();
    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpAndSettle();

    final greetingFinder = find.byWidgetPredicate(
      (widget) => widget is Text && widget.data?.startsWith('Good ') == true,
    );
    final greeting = tester.widget<Text>(greetingFinder);
    expect(greeting.maxLines, 1);

    await tester.ensureVisible(find.text('Suction'));
    await tester.tap(find.text('Suction'));
    await tester.pumpAndSettle();
    expect(find.text('Suction power'), findsOneWidget);
    expect(find.text('Turbo'), findsOneWidget);
    await tester.tap(find.text('Turbo'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Travelled'));
    await tester.tap(find.text('Travelled'));
    await tester.pumpAndSettle();
    expect(find.text('Distance travelled'), findsOneWidget);
    Navigator.of(tester.element(find.text('Distance travelled'))).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Rooms').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Cleaning power'));
    final balanced = tester.widget<Text>(find.text('Balanced'));
    expect(balanced.maxLines, 1);
    expect(balanced.softWrap, isFalse);
    expect(tester.takeException(), isNull);
  });
}
