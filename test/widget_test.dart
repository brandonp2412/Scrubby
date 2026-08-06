// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:scrubby/main.dart';
import 'package:scrubby/core/app_state.dart';
import 'package:scrubby/core/home_assistant.dart';
import 'package:scrubby/screens/dashboard_shell.dart';

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

  test('shows only the device portion of a repeated friendly name', () {
    VacuumEntity entityWith(String friendlyName) => VacuumEntity.fromJson({
      'entity_id': 'vacuum.test',
      'state': 'docked',
      'attributes': {'friendly_name': friendlyName},
    });

    expect(entityWith('FloorSlut FloorSlut').name, 'FloorSlut');
    expect(
      entityWith('Living Room Vacuum Living Room Vacuum').name,
      'Living Room Vacuum',
    );
    expect(entityWith('Living Room Vacuum').name, 'Living Room Vacuum');
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

  testWidgets('asks for confirmation before logging out', (
    WidgetTester tester,
  ) async {
    final state = AppState(secureStorage: const _FakeSecureStorage())
      ..startDemo();
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(home: DashboardShell(state: state)));

    await tester.tap(find.byTooltip('Disconnect'));
    await tester.pumpAndSettle();

    expect(find.text('Log out?'), findsOneWidget);
    expect(
      find.text(
        'You’ll need to reconnect to Home Assistant to use Scrubby again.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Today at a glance'), findsOneWidget);

    await tester.tap(find.byTooltip('Disconnect'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();
    expect(state.vacuums, isEmpty);
  });
}

class _FakeSecureStorage extends FlutterSecureStorage {
  const _FakeSecureStorage();

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {}
}
