import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:scrubby/core/app_state.dart';
import 'package:scrubby/core/home_assistant.dart';
import 'package:scrubby/screens/dashboard_shell.dart';
import 'package:scrubby/screens/login_screen.dart';
import 'package:scrubby/theme.dart';

const _demoMapPng =
    'iVBORw0KGgoAAAANSUhEUgAAAPAAAACgEAIAAADtKapxAAADeklEQVR42u3csU7qYBiA4faEC2D3RlxIXIxxdWI3JkwOUobKIAzSBR2cTIw7k6sxLiQuXATrvzh5B3XwDC4YagELfZ7JSFuSj79vmkIahxDCfB4BUDH/jABAoAEQaACBBkCgAeqlscxGp53h6LxrWPyVx/ury7ubMkewhtnGte0KGqCiBBpAoAEoomEErFucxWdx9vM2eZo/5KlZsV3r+Wvd/rzCy6ztFQR6nA3648zHRhlJNIiSP3t3a5hfyqJ+lK1vbbvFAVBRAg0g0AAINIBAAyDQAAINgEADINAAAg2AQAMINAACDYBAAwg0AMV5YD9bYNJ+OX66LXWIZtQyRwQaVu61OWtNgzkg0FA5hx/7bwd7Eo9AQ+W0J0fPJxelAt2ZjaZdk2S7+JIQQKABEGgAgQZAoAEEGgCBBkCgAQQaAIEGEGgABBoAgQYQaAAEGkCgARBoAIEGQKABEGgAgQZAoAEEGgCBBkCgAQQaAIEGEGgABBpAoAEQaAAEGkCgARBoAIEGQKABEGgAgQZAoAEEGgCBBqi9RvlDJOngOkmNku3Vi4bvvYWv5mn+kP9f4XEWn8XZz9tAhQIN2275vAoxm+QWB4BAAyDQADsgDiGE+bzOI5i0X46fbl+bs9Y0HH7svx3stSdHzycXFgfgChoAgQYQaAAEGkCgARBoAJb6md1pZzg67xrWbni8v7q8uym6lzUAmz8fXUEDVJRAAwg0AEV43OhWWvRU4i8eiQmrOpsWnVPL7FX+fFxBoMfZoD/OfMzVkUSDKNnoO1oD7Lgs6kfZ5s9HtzgAKkqgAQQaAIEGEGgABBpAoAEQaAAEGkCgARBoAIEGQKABEGgAgQZAoAEEGgCBBhBoAAQaAIEGEGgABBpAoAEQaAAEGkCgAfithhHUzaT9cvx0W3i3ZtQyOxBo1uq1OWtNgzmAQFM5hx/7bwd7sg4CTeW0J0fPJxeFA92ZjaZd04NN8iUhgEADINAAAg2AQAMINAACDYBAAwg0AAININAACDQAAg0g0AAINIBAAyDQAAINgEADINAAAg2AQAMINAACDYBAAwg0AAININAACDRAjTXKHyJJB9dJapR11ouG770C2+dp/pCncRafxdmiV7/+/r7N9/+DQEOB4K5jL1GmztziABBoAAQaYAfEIYQwnxsEgCtoAAQaQKABEGiAuvgEJoTWvwdNdZkAAAAASUVORK5CYII=';

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

AppState _buildState() {
  final state = AppState(secureStorage: const _FakeSecureStorage())
    ..startDemo();
  state.mapRoomLabels.clear();
  state.vacuums = [
    VacuumEntity(
      entityId: state.vacuums[0].entityId,
      name: state.vacuums[0].name,
      state: state.vacuums[0].state,
      battery: state.vacuums[0].battery,
      mapImage: base64Decode(_demoMapPng),
    ),
  ];

  state.schedules.addAll([
    const CleaningSchedule(
      id: 'demo-weekday',
      entityId: 'automation.scrubby_demo_weekday',
      title: 'Weekday morning',
      weekdays: [1, 2, 3, 4, 5],
      time: '09:00',
      vacuumEntityId: 'vacuum.orbit',
      enabled: true,
      fanSpeed: 'Balanced',
      segmentIds: ['1', '2', '3', '4'],
    ),
    const CleaningSchedule(
      id: 'demo-weekend',
      entityId: 'automation.scrubby_demo_weekend',
      title: 'Deep clean',
      weekdays: [6, 7],
      time: '13:00',
      vacuumEntityId: 'vacuum.orbit',
      enabled: true,
      fanSpeed: 'Turbo',
      segmentIds: [],
      cycles: 2,
    ),
  ]);

  return state;
}

Future<void> _takeScreenshot({
  required IntegrationTestWidgetsFlutterBinding binding,
  required WidgetTester tester,
  required String screenshotName,
}) async {
  await tester.pumpAndSettle();
  if (!kIsWeb) await binding.convertFlutterSurfaceToImage();
  await tester.pumpAndSettle();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pumpAndSettle();
  await binding.takeScreenshot(screenshotName);
}

Future<void> _pumpDashboard(
  WidgetTester tester,
  AppState state, {
  int tab = 0,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildTheme(),
      home: DashboardShell(state: state),
    ),
  );
  await tester.pumpAndSettle();
  if (tab != 0) {
    await tester.tap(find.text(['Home', 'Schedule', 'Rooms'][tab]));
    await tester.pumpAndSettle();
  }
}

const _only = String.fromEnvironment('SCREENSHOT_ONLY');

bool _skip(String name) => _only.isNotEmpty && _only != name;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => FlutterSecureStorage.setMockInitialValues({}));

  group('Generate default screenshots', () {
    testWidgets('HomePage', (tester) async {
      final state = _buildState();
      await _pumpDashboard(tester, state);
      await tester.tap(find.text('Schedule'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();
      await _takeScreenshot(
        binding: binding,
        tester: tester,
        screenshotName: '1_en-US',
      );
    }, skip: _skip('HomePage'));

    testWidgets('SchedulesPage', (tester) async {
      final state = _buildState();
      await _pumpDashboard(tester, state, tab: 1);
      await _takeScreenshot(
        binding: binding,
        tester: tester,
        screenshotName: '2_en-US',
      );
    }, skip: _skip('SchedulesPage'));

    testWidgets('RoomsPage', (tester) async {
      final state = _buildState();
      await _pumpDashboard(tester, state, tab: 2);
      await _takeScreenshot(
        binding: binding,
        tester: tester,
        screenshotName: '3_en-US',
      );
    }, skip: _skip('RoomsPage'));

    testWidgets('SettingsPage', (tester) async {
      final state = _buildState();
      await _pumpDashboard(tester, state);
      await tester.tap(find.bySemanticsLabel('Open Orbit settings'));
      await tester.pumpAndSettle();
      await _takeScreenshot(
        binding: binding,
        tester: tester,
        screenshotName: '4_en-US',
      );
    }, skip: _skip('SettingsPage'));

    testWidgets('LoginScreen', (tester) async {
      final state = AppState(secureStorage: const _FakeSecureStorage());
      state.isInitialized = true;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          home: LoginScreen(key: const ValueKey('login'), state: state),
        ),
      );
      await _takeScreenshot(
        binding: binding,
        tester: tester,
        screenshotName: '5_en-US',
      );
    }, skip: _skip('LoginScreen'));
  });
}
