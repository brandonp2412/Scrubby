import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:patrol/patrol.dart';
import 'package:scrubby/core/home_assistant.dart';
import 'package:scrubby/core/notifications.dart';

void main() {
  const notifications = <DreameNotification>[
    DreameNotification(
      category: DreameNotificationCategory.cleanup,
      entityId: 'vacuum.orbit',
      title: 'Cleaning complete',
      body: 'Patrol cleanup notification',
    ),
    DreameNotification(
      category: DreameNotificationCategory.consumable,
      entityId: 'vacuum.orbit',
      title: 'Maintenance needed',
      body: 'Patrol consumable notification',
    ),
    DreameNotification(
      category: DreameNotificationCategory.information,
      entityId: 'vacuum.orbit',
      title: 'Robot information',
      body: 'Patrol information notification',
    ),
    DreameNotification(
      category: DreameNotificationCategory.warning,
      entityId: 'vacuum.orbit',
      title: 'Robot warning',
      body: 'Patrol warning notification',
    ),
    DreameNotification(
      category: DreameNotificationCategory.error,
      entityId: 'vacuum.orbit',
      title: 'Robot error',
      body: 'Patrol error notification',
    ),
  ];

  for (final notification in notifications) {
    patrolTest('posts the ${notification.category.name} notification', (
      $,
    ) async {
      if (!Platform.isAndroid) return;

      await $.pumpWidgetAndSettle(
        const MaterialApp(home: Scaffold(body: Text('Notification test'))),
      );

      final presenter = LocalVacuumNotificationPresenter.instance;
      await presenter.initialize();

      final androidNotifications = FlutterLocalNotificationsPlugin()
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()!;
      expect(await androidNotifications.areNotificationsEnabled(), isTrue);

      await presenter.show(notification, vacuumName: 'Orbit');

      await $.platform.mobile.openNotifications();
      await $.platform.mobile.waitUntilVisible(
        Selector(textContains: notification.body),
        timeout: const Duration(seconds: 10),
      );
      await $.platform.mobile.closeNotifications();
    });
  }
}
