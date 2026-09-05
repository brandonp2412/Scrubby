import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:scrubby/core/app_state.dart';
import 'package:scrubby/core/home_assistant.dart';
import 'package:scrubby/screens/dashboard_shell.dart';
import 'package:scrubby/screens/login_screen.dart';
import 'package:scrubby/theme.dart';

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

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  expect(finder, findsWidgets);
  await tester.ensureVisible(finder.first);
  await tester.tap(finder.first);
  await _settle(tester);
  expect(tester.takeException(), isNull);
}

Finder _formDropdown(String label) => find.byWidgetPredicate(
  (widget) =>
      widget is DropdownButtonFormField && widget.decoration.labelText == label,
);

Future<AppState> _pumpLoginFlow(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(1280, 900));
  final state = AppState(secureStorage: const _FakeSecureStorage())
    ..isInitialized = true;
  await tester.pumpWidget(
    MaterialApp(
      theme: buildTheme(),
      home: ListenableBuilder(
        listenable: state,
        builder: (context, _) => state.vacuums.isEmpty
            ? LoginScreen(state: state)
            : DashboardShell(state: state),
      ),
    ),
  );
  await _settle(tester);
  expect(tester.takeException(), isNull);
  return state;
}

Future<AppState> _pumpDashboard(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(1280, 900));
  final state = AppState()..startDemo();
  state.mapRoomLabels.removeLast();
  final vacuum = state.vacuums.first;
  state.vacuums[0] = VacuumEntity(
    entityId: vacuum.entityId,
    name: vacuum.name,
    state: vacuum.state,
    battery: vacuum.battery,
    fanSpeed: vacuum.fanSpeed,
    fanSpeeds: vacuum.fanSpeeds,
    mapImage: base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
    ),
  );
  state.schedules.add(
    const CleaningSchedule(
      id: 'demo-morning',
      entityId: '',
      title: 'Morning clean',
      weekdays: [DateTime.monday, DateTime.wednesday],
      time: '09:00',
      vacuumEntityId: 'vacuum.orbit',
      fanSpeed: 'Balanced',
      segmentIds: ['1'],
    ),
  );
  await tester.pumpWidget(
    MaterialApp(
      theme: buildTheme(),
      home: ListenableBuilder(
        listenable: state,
        builder: (context, _) => DashboardShell(state: state),
      ),
    ),
  );
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
  return state;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() async {
    TestWidgetsFlutterBinding.instance.platformDispatcher.clearAllTestValues();
  });

  testWidgets('clicks through login, demo entry, and confirmed logout', (
    tester,
  ) async {
    final state = await _pumpLoginFlow(tester);
    addTearDown(state.dispose);

    expect(find.text('Connect your home'), findsOneWidget);
    final fields = find.byType(TextField);
    expect(fields, findsNWidgets(2));
    final token = fields.at(1);
    expect(tester.widget<TextField>(token).obscureText, isTrue);
    await _tap(tester, find.byIcon(Icons.visibility_outlined));
    expect(tester.widget<TextField>(token).obscureText, isFalse);
    await _tap(tester, find.byIcon(Icons.visibility_off_outlined));
    expect(tester.widget<TextField>(token).obscureText, isTrue);

    await tester.enterText(fields.first, 'http://homeassistant.local:8123');
    await tester.enterText(token, '');
    await _tap(tester, find.text('Connect Home Assistant'));
    expect(
      find.text('Enter your Home Assistant address and access token.'),
      findsOneWidget,
    );

    await tester.enterText(fields.first, 'not-a-url');
    await tester.enterText(token, 'token');
    await _tap(tester, find.text('Connect Home Assistant'));
    expect(
      find.text(
        'Enter a valid Home Assistant URL, including http:// or https://.',
      ),
      findsOneWidget,
    );

    await _tap(tester, find.text('Explore with demo home'));
    expect(find.text('Today at a glance'), findsOneWidget);
    await _tap(tester, find.text('Disconnect'));
    expect(find.text('Log out?'), findsOneWidget);
    await _tap(tester, find.text('Log out'));
    expect(find.text('Connect your home'), findsOneWidget);
    await _tap(tester, find.text('Explore with demo home'));
    expect(find.text('Today at a glance'), findsOneWidget);
  });

  testWidgets('clicks through home, history, map, and settings', (
    tester,
  ) async {
    final state = await _pumpDashboard(tester);
    addTearDown(state.dispose);

    await _tap(tester, find.text('Suction'));
    expect(find.text('Suction power'), findsOneWidget);
    await _tap(tester, find.text('Turbo'));
    expect(state.vacuum.fanSpeed, 'Turbo');

    for (final metric in ['Travelled', 'Cleaned', 'Run time']) {
      await _tap(tester, find.text(metric));
      expect(find.text('Cleaning history'), findsOneWidget);
      await _tap(tester, find.text('Overview'));
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }

    await _tap(tester, find.text('Today at a glance'));
    expect(find.text('Cleaning history'), findsOneWidget);
    for (final metric in ['Travelled', 'Cleaned', 'Run time', 'Overview']) {
      await _tap(tester, find.text(metric));
    }
    await tester.pageBack();
    await tester.pumpAndSettle();

    await _tap(
      tester,
      find.byKey(const ValueKey('notification-history-preview')),
    );
    expect(find.text('Notification history'), findsWidgets);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await _tap(tester, find.byType(Image));
    expect(find.text('Orbit map'), findsOneWidget);
    await _tap(tester, find.byTooltip('Zoom in'));
    await _tap(tester, find.byTooltip('Zoom out'));
    await _tap(tester, find.byTooltip('Name a room'));
    expect(find.text('Label this room'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, 'Office');
    await _tap(tester, find.text('Add label'));
    final office = find.textContaining('Office', findRichText: true);
    expect(office, findsOneWidget);
    expect(find.byTooltip('Name a room'), findsNothing);
    await _tap(tester, office);
    expect(find.text('Rename room'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, 'Hallway');
    await _tap(tester, find.text('Save name'));
    expect(find.textContaining('Hallway', findRichText: true), findsOneWidget);
    await tester.pageBack();
    await _settle(tester);

    await _tap(tester, find.text('Orbit').first);
    expect(find.text('Orbit settings'), findsOneWidget);
    await _tap(tester, find.byKey(const ValueKey('edit-vacuum-name')));
    expect(find.text('Edit vacuum name'), findsWidgets);
    await _tap(tester, find.text('Cancel'));
    await _tap(tester, find.byKey(const ValueKey('edit-vacuum-name')));
    await tester.enterText(find.byType(TextFormField).last, 'Orbit Windows');
    await _tap(tester, find.text('Save'));
    expect(state.vacuum.name, 'Orbit Windows');
    expect(find.text('Orbit Windows settings'), findsOneWidget);

    final search = find.byKey(const ValueKey('settings-search'));
    await tester.enterText(search, 'nothing matches this');
    await tester.pumpAndSettle();
    expect(find.textContaining('No settings match'), findsOneWidget);
    await _tap(tester, find.byTooltip('Clear search'));

    final firstSelect = find.byType(DropdownButton<String>).first;
    await tester.ensureVisible(firstSelect);
    await tester.tap(firstSelect);
    await _settle(tester);
    await _tap(tester, find.text('Routine cleaning').last);
    expect(
      state.vacuumSettings
          .firstWhere(
            (setting) => setting.entityId == 'select.orbit_cleangenius',
          )
          .value,
      'Routine cleaning',
    );
    expect(find.text('Routine cleaning'), findsOneWidget);

    final firstSwitch = find.byType(Switch).first;
    await tester.ensureVisible(firstSwitch);
    await tester.tap(firstSwitch);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    final slider = find.byType(Slider).first;
    await tester.ensureVisible(slider);
    await tester.drag(slider, const Offset(60, 0));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await _tap(tester, find.text('Refresh supported settings'));
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('clicks through cleaning controls, schedules, and rooms', (
    tester,
  ) async {
    final state = await _pumpDashboard(tester);
    addTearDown(state.dispose);

    await _tap(tester, find.text('Find'));
    await _tap(tester, find.text('Dock'));

    final start = find.text('START');
    await tester.ensureVisible(start);
    await tester.tap(start);
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('PAUSE'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('PAUSE'));
    await tester.pumpAndSettle();
    expect(find.text('RESUME'), findsOneWidget);
    await tester.tap(find.text('RESUME'));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('PAUSE'), findsOneWidget);
    await tester.tap(find.text('PAUSE'));
    await tester.pumpAndSettle();
    expect(find.text('RESUME'), findsOneWidget);
    await _tap(tester, find.text('End clean'));
    expect(find.text('START'), findsOneWidget);

    await _tap(tester, find.byKey(const ValueKey('dashboard-tab-1')));
    expect(find.text('Morning clean'), findsOneWidget);

    await _tap(tester, find.text('Morning clean'));
    expect(find.text('Edit schedule'), findsOneWidget);
    await _tap(tester, find.byIcon(Icons.close));

    await _tap(tester, find.text('New schedule'));
    expect(find.text('New schedule'), findsWidgets);
    await tester.enterText(find.byType(TextField).first, 'Windows E2E');
    await _tap(tester, find.text('Start time'));
    expect(find.text('Cancel'), findsOneWidget);
    await _tap(tester, find.text('Cancel'));
    await _tap(tester, find.text('Create schedule'));
    expect(find.text('Windows E2E'), findsOneWidget);

    await _tap(tester, find.byTooltip('Delete schedule').last);
    expect(find.text('Delete schedule?'), findsOneWidget);
    await _tap(tester, find.text('Cancel'));
    await _tap(tester, find.byTooltip('Delete schedule').last);
    await _tap(tester, find.text('Delete'));
    expect(find.text('Windows E2E'), findsNothing);

    await _tap(tester, find.byKey(const ValueKey('dashboard-tab-2')));
    expect(find.text('Kitchen'), findsOneWidget);
    await _tap(tester, find.text('Kitchen'));
    await _tap(tester, find.text('Living room'));
    expect(find.text('Clean 2 rooms'), findsOneWidget);

    await _tap(tester, find.byKey(const ValueKey('manual-cleaning-mode')));
    await _tap(tester, find.text('Mop').last);
    expect(_formDropdown('Suction power'), findsNothing);
    await _tap(tester, find.byKey(const ValueKey('manual-cleaning-mode')));
    await _tap(tester, find.text('Vacuum & mop').last);
    expect(_formDropdown('Suction power'), findsOneWidget);
    await _tap(tester, _formDropdown('Suction power'));
    await _tap(tester, find.text('Turbo').last);

    final clean = find.text('Clean 2 rooms');
    await tester.ensureVisible(clean);
    await tester.tap(clean);
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.textContaining('Cleaning started'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('clicks through every schedule editor control', (tester) async {
    final state = await _pumpDashboard(tester);
    addTearDown(state.dispose);

    await _tap(tester, find.byKey(const ValueKey('dashboard-tab-1')));
    await _tap(tester, find.text('New schedule'));
    await tester.enterText(find.byType(TextField).first, 'Windows exhaustive');

    await _tap(tester, find.text('Start time'));
    await _tap(tester, find.text('OK'));

    await _tap(tester, find.widgetWithText(FilterChip, 'M'));
    await _tap(tester, find.widgetWithText(FilterChip, 'S').first);

    await _tap(tester, _formDropdown('Vacuum'));
    await _tap(tester, find.text('Mini').last);
    expect(_formDropdown('CleanGenius'), findsNothing);
    await _tap(tester, _formDropdown('Vacuum'));
    await _tap(tester, find.text('Orbit').last);
    expect(_formDropdown('CleanGenius'), findsOneWidget);

    await _tap(tester, find.widgetWithText(FilterChip, 'Kitchen'));
    expect(_formDropdown('Cycles'), findsOneWidget);
    await _tap(tester, find.widgetWithText(FilterChip, 'Kitchen'));
    expect(_formDropdown('Cycles'), findsNothing);
    await _tap(tester, find.widgetWithText(FilterChip, 'Kitchen'));
    await _tap(tester, find.widgetWithText(FilterChip, 'Whole home'));
    expect(_formDropdown('Cycles'), findsNothing);
    await _tap(tester, find.widgetWithText(FilterChip, 'Kitchen'));
    expect(_formDropdown('Cycles'), findsOneWidget);

    await _tap(tester, _formDropdown('CleanGenius'));
    await _tap(tester, find.text('Routine cleaning').last);
    expect(_formDropdown('Cleaning mode'), findsNothing);
    await _tap(tester, _formDropdown('CleanGenius'));
    await _tap(tester, find.text('Custom').last);

    await _tap(tester, _formDropdown('Cleaning mode'));
    await _tap(tester, find.text('Mop').last);
    expect(_formDropdown('Suction power'), findsNothing);
    await _tap(tester, _formDropdown('Cleaning mode'));
    await _tap(tester, find.text('Vacuum & mop').last);
    expect(_formDropdown('Suction power'), findsOneWidget);

    await _tap(tester, _formDropdown('Suction power'));
    await _tap(tester, find.text('Turbo').last);
    await _tap(tester, _formDropdown('Cleaning route'));
    await _tap(tester, find.text('Deep').last);
    await _tap(tester, _formDropdown('Cycles'));
    await _tap(tester, find.text('2 cycles').last);

    await _tap(tester, find.text('Create schedule'));
    expect(find.text('Windows exhaustive'), findsOneWidget);
    final created = state.schedules.firstWhere(
      (schedule) => schedule.title == 'Windows exhaustive',
    );
    expect(created.segmentIds, ['1']);
    expect(created.cycles, 2);
    expect(created.fanSpeed, 'Turbo');
    expect(
      created.settings
          .firstWhere(
            (setting) => setting.entityId == 'select.orbit_cleaning_route',
          )
          .value,
      'Deep',
    );

    final switches = find.byType(Switch);
    await tester.ensureVisible(switches.last);
    await tester.tap(switches.last);
    await _settle(tester);
    expect(
      state.schedules
          .firstWhere((schedule) => schedule.id == created.id)
          .enabled,
      isFalse,
    );

    await _tap(tester, find.text('Windows exhaustive'));
    expect(find.text('Edit schedule'), findsOneWidget);
    await _tap(tester, find.text('Save changes'));

    final handles = find.byTooltip('Reorder schedule');
    expect(handles, findsNWidgets(2));
    await tester.ensureVisible(handles.last);
    await tester.drag(handles.last, const Offset(0, -180));
    await _settle(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('clicks through vacuum selection and disconnect confirmation', (
    tester,
  ) async {
    final state = await _pumpDashboard(tester);
    addTearDown(state.dispose);

    await _tap(tester, find.byIcon(Icons.expand_more_rounded));
    await _tap(tester, find.text('Mini'));
    expect(state.vacuum.name, 'Mini');
    expect(find.text('No map entity found'), findsOneWidget);
    await _tap(tester, find.text('No map entity found'));
    expect(find.text('Mini map'), findsOneWidget);
    await tester.pageBack();
    await _settle(tester);

    await _tap(tester, find.text('Mini').first);
    expect(find.text('Mini settings'), findsOneWidget);
    expect(
      find.textContaining('did not expose any configurable'),
      findsOneWidget,
    );
    await _tap(tester, find.text('Try again'));
    await tester.pageBack();
    await _settle(tester);

    await _tap(tester, find.byKey(const ValueKey('dashboard-tab-2')));
    expect(
      find.textContaining('did not report any cleanable rooms'),
      findsOneWidget,
    );
    await _tap(tester, find.byKey(const ValueKey('dashboard-tab-0')));

    await _tap(tester, find.byIcon(Icons.expand_more_rounded));
    await _tap(tester, find.text('Orbit').last);
    expect(state.vacuum.name, 'Orbit');

    await _tap(tester, find.text('Disconnect'));
    expect(find.text('Log out?'), findsOneWidget);
    await _tap(tester, find.text('Cancel'));
  });
}
