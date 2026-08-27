import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scrubby/core/app_state.dart';
import 'package:scrubby/core/home_assistant.dart';

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test(
    'collapses persistent notification duplicates but keeps cleanups',
    () async {
      final newest = DateTime.utc(2026, 8, 27, 12);
      final older = newest.subtract(const Duration(hours: 1));
      final history = [
        {
          'category': 'consumable',
          'entity_id': 'vacuum.dreame',
          'title': 'Maintenance needed',
          'body': 'Clean the sensors and reset their counter.',
          'created_at': newest.toIso8601String(),
        },
        {
          'category': 'consumable',
          'entity_id': 'vacuum.dreame',
          'title': 'Maintenance needed',
          'body': 'Clean the sensors and reset their counter.',
          'created_at': older.toIso8601String(),
        },
        {
          'category': 'cleanup',
          'entity_id': 'vacuum.dreame',
          'title': 'Cleanup completed',
          'body': '42 m² · 55 min',
          'created_at': newest.toIso8601String(),
        },
        {
          'category': 'cleanup',
          'entity_id': 'vacuum.dreame',
          'title': 'Cleanup completed',
          'body': '42 m² · 55 min',
          'created_at': older.toIso8601String(),
        },
      ];
      FlutterSecureStorage.setMockInitialValues({
        'notification_history': jsonEncode(history),
      });

      final state = AppState();
      await state.initialize();

      final maintenance = state.notificationHistory.where(
        (item) => item.category == DreameNotificationCategory.consumable,
      );
      final cleanups = state.notificationHistory.where(
        (item) => item.category == DreameNotificationCategory.cleanup,
      );

      expect(maintenance, hasLength(1));
      expect(maintenance.single.createdAt, newest);
      expect(cleanups, hasLength(2));
    },
  );
}
