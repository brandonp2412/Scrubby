import 'dart:async';
import 'dart:ui' show DartPluginRegistrant;

import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'home_assistant.dart';

/// Displays Dreame events using a separate operating-system category for each
/// notification family exposed by the Home Assistant integration.
abstract interface class VacuumNotificationPresenter {
  Future<void> initialize();

  Future<bool> requestPermissions();

  Future<void> show(DreameNotification notification, {String? vacuumName});
}

const _backgroundChannelId = 'scrubby_background_service';
const _backgroundNotificationId = 5100;

bool get _supportsAndroidService =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

Future<void> configureBackgroundNotificationService() async {
  if (!_supportsAndroidService) return;
  final notifications = FlutterLocalNotificationsPlugin();
  await notifications
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(
        const AndroidNotificationChannel(
          _backgroundChannelId,
          'Scrubby connection',
          description: 'Keeps Dreame event monitoring active in the background',
          importance: Importance.low,
        ),
      );
  await FlutterBackgroundService().configure(
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: _backgroundServiceEntrypoint,
      onBackground: _iosBackground,
    ),
    androidConfiguration: AndroidConfiguration(
      autoStart: false,
      autoStartOnBoot: false,
      onStart: _backgroundServiceEntrypoint,
      isForegroundMode: true,
      notificationChannelId: _backgroundChannelId,
      initialNotificationTitle: 'Scrubby',
      initialNotificationContent: 'Keeping Dreame monitoring active',
      foregroundServiceNotificationId: _backgroundNotificationId,
      foregroundServiceTypes: const [AndroidForegroundType.remoteMessaging],
    ),
  );
}

Future<bool> _iosBackground(ServiceInstance service) async => true;

Future<void> startBackgroundNotificationService() async {
  if (!_supportsAndroidService) return;
  try {
    await FlutterBackgroundService().startService();
  } catch (_) {
    // The plugin is intentionally unavailable on desktop and in widget tests.
  }
}

Future<void> stopBackgroundNotificationService() async {
  if (!_supportsAndroidService) return;
  try {
    FlutterBackgroundService().invoke('stop');
  } catch (_) {
    // The plugin is intentionally unavailable on desktop and in widget tests.
  }
}

/// Entry point for the Android foreground-service isolate. It reads the same
/// securely stored credentials as the UI isolate and owns a second HA socket
/// only while the app is backgrounded.
@pragma('vm:entry-point')
Future<void> _backgroundServiceEntrypoint(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  if (service is AndroidServiceInstance) {
    await service.setAsForegroundService();
  }
  StreamSubscription<DreameNotification>? notifications;
  HomeAssistantClient? client;
  var stopping = false;

  Future<void> stop() async {
    if (stopping) return;
    stopping = true;
    await notifications?.cancel();
    await client?.close();
    await service.stopSelf();
  }

  service.on('stop').listen((_) => stop());
  const storage = FlutterSecureStorage();
  final credentials = await storage.readAll();
  final url = credentials['home_assistant_url'];
  final token = credentials['home_assistant_token'];
  if (url == null || token == null || url.isEmpty || token.isEmpty) {
    await stop();
    return;
  }

  try {
    client = HomeAssistantClient(url, token);
    await client.connect();
    final vacuums = await client.fetchVacuums();
    final names = {for (final vacuum in vacuums) vacuum.entityId: vacuum.name};
    notifications = client.notificationUpdates.listen((notification) {
      unawaited(
        LocalVacuumNotificationPresenter.instance.show(
          notification,
          vacuumName: names[notification.entityId],
        ),
      );
    });
  } catch (_) {
    await stop();
  }
}

class LocalVacuumNotificationPresenter implements VacuumNotificationPresenter {
  LocalVacuumNotificationPresenter._();

  static final instance = LocalVacuumNotificationPresenter._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  Future<void>? _initialization;
  bool _supported = true;

  static const _categories = <DarwinNotificationCategory>[
    DarwinNotificationCategory('dreame_cleanup'),
    DarwinNotificationCategory('dreame_consumables'),
    DarwinNotificationCategory('dreame_information'),
    DarwinNotificationCategory('dreame_warnings'),
    DarwinNotificationCategory('dreame_errors'),
  ];

  static const _androidChannels = <AndroidNotificationChannel>[
    AndroidNotificationChannel(
      'dreame_cleanup',
      'Cleaning activity',
      description: 'Cleaning started, finished, and cleaning summaries',
      importance: Importance.defaultImportance,
    ),
    AndroidNotificationChannel(
      'dreame_consumables',
      'Consumables',
      description: 'Brush, filter, sensor, mop, and detergent maintenance',
      importance: Importance.defaultImportance,
    ),
    AndroidNotificationChannel(
      'dreame_information',
      'Robot information',
      description: 'Auto-empty, paused cleaning, and other robot information',
      importance: Importance.low,
    ),
    AndroidNotificationChannel(
      'dreame_warnings',
      'Robot warnings',
      description: 'Conditions that need attention soon',
      importance: Importance.high,
    ),
    AndroidNotificationChannel(
      'dreame_errors',
      'Robot errors',
      description: 'Robot faults that need immediate attention',
      importance: Importance.max,
    ),
  ];

  bool get _isSupportedPlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  @override
  Future<void> initialize() => _initialization ??= _initialize();

  Future<void> _initialize() async {
    if (!_isSupportedPlatform) {
      _supported = false;
      return;
    }
    try {
      const android = AndroidInitializationSettings('ic_launcher');
      const darwin = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
        notificationCategories: _categories,
      );
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: android,
          iOS: darwin,
          macOS: darwin,
        ),
      );
      final androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      for (final channel in _androidChannels) {
        await androidPlugin?.createNotificationChannel(channel);
      }
    } catch (_) {
      // A notification plugin failure must never prevent Home Assistant login.
      _supported = false;
    }
  }

  @override
  Future<bool> requestPermissions() async {
    await initialize();
    if (!_supported) return false;
    if (defaultTargetPlatform == TargetPlatform.android) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()
              ?.requestNotificationsPermission() ??
          false;
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin
              >()
              ?.requestPermissions(alert: true, badge: true, sound: true) ??
          false;
    }
    return await _plugin
            .resolvePlatformSpecificImplementation<
              MacOSFlutterLocalNotificationsPlugin
            >()
            ?.requestPermissions(alert: true, badge: true, sound: true) ??
        false;
  }

  @override
  Future<void> show(
    DreameNotification notification, {
    String? vacuumName,
  }) async {
    await initialize();
    if (!_supported) return;
    final channel = notification.category;
    final androidChannel = _androidChannels.firstWhere(
      (item) => item.id == channel.channelId,
    );
    final titlePrefix = vacuumName?.trim();
    final title = titlePrefix == null || titlePrefix.isEmpty
        ? notification.title
        : '$titlePrefix · ${notification.title}';
    await _plugin.show(
      id: DateTime.now().microsecondsSinceEpoch & 0x7fffffff,
      title: title,
      body: notification.body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          androidChannel.id,
          androidChannel.name,
          channelDescription: androidChannel.description,
          importance: androidChannel.importance,
          priority: channel.priority,
          category: channel.androidCategory,
        ),
        iOS: DarwinNotificationDetails(
          categoryIdentifier: channel.channelId,
          interruptionLevel: channel.interruptionLevel,
        ),
        macOS: DarwinNotificationDetails(
          categoryIdentifier: channel.channelId,
          interruptionLevel: channel.interruptionLevel,
        ),
      ),
      payload: notification.entityId,
    );
  }
}

extension on DreameNotificationCategory {
  String get channelId => switch (this) {
    DreameNotificationCategory.cleanup => 'dreame_cleanup',
    DreameNotificationCategory.consumable => 'dreame_consumables',
    DreameNotificationCategory.information => 'dreame_information',
    DreameNotificationCategory.warning => 'dreame_warnings',
    DreameNotificationCategory.error => 'dreame_errors',
  };

  Priority get priority => switch (this) {
    DreameNotificationCategory.error => Priority.max,
    DreameNotificationCategory.warning => Priority.high,
    DreameNotificationCategory.information => Priority.low,
    _ => Priority.defaultPriority,
  };

  AndroidNotificationCategory get androidCategory => switch (this) {
    DreameNotificationCategory.error ||
    DreameNotificationCategory.warning => AndroidNotificationCategory.alarm,
    DreameNotificationCategory.cleanup => AndroidNotificationCategory.status,
    _ => AndroidNotificationCategory.reminder,
  };

  InterruptionLevel get interruptionLevel => switch (this) {
    DreameNotificationCategory.error => InterruptionLevel.timeSensitive,
    DreameNotificationCategory.warning => InterruptionLevel.active,
    DreameNotificationCategory.information => InterruptionLevel.passive,
    _ => InterruptionLevel.active,
  };
}
