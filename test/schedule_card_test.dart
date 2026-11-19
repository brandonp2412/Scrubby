import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scrubby/core/app_state.dart';
import 'package:scrubby/core/home_assistant.dart';
import 'package:scrubby/screens/schedules_page.dart';

void main() {
  testWidgets(
    'schedule cards omit cleaning settings without hiding enabled status',
    (tester) async {
      final state = AppState()..startDemo();
      addTearDown(state.dispose);
      state.schedules.addAll(const [
        CleaningSchedule(
          id: 'scrubby_casual',
          entityId: 'automation.scrubby_casual',
          title: 'Casual',
          weekdays: [DateTime.monday],
          time: '12:00',
          vacuumEntityId: 'vacuum.orbit',
          fanSpeed: 'off',
          settings: [
            VacuumSetting(
              entityId: 'switch.orbit_mop',
              name: 'Mop',
              kind: VacuumSettingKind.toggle,
              value: 'off',
            ),
            VacuumSetting(
              entityId: 'select.orbit_cleaning_route',
              name: 'Cleaning route',
              kind: VacuumSettingKind.select,
              value: 'sweeping_and_mopping',
            ),
          ],
        ),
        CleaningSchedule(
          id: 'scrubby_eviscerate',
          entityId: 'automation.scrubby_eviscerate',
          title: 'Eviscerate',
          weekdays: [DateTime.friday],
          time: '12:00',
          vacuumEntityId: 'vacuum.orbit',
          fanSpeed: 'off',
        ),
      ]);

      await tester.binding.setSurfaceSize(const Size(800, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: SchedulesPage(state: state)),
          ),
        ),
      );

      expect(find.text('Casual'), findsOneWidget);
      expect(find.text('Eviscerate'), findsOneWidget);
      expect(find.text('Whole home · Orbit'), findsNWidgets(2));
      expect(find.textContaining('off'), findsNothing);
      expect(find.textContaining('sweeping_and_mopping'), findsNothing);
      expect(
        tester.widgetList<Switch>(find.byType(Switch)).map((s) => s.value),
        [true, true],
      );
    },
  );
}
