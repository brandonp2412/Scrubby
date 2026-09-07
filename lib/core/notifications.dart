import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'home_assistant.dart';
import '../logging.dart';

/// Displays Dreame events using a separate operating-system category for each
/// notification family exposed by the Home Assistant integration.
abstract interface class VacuumNotificationPresenter {
  Future<void> initialize();

  Future<bool> requestPermissions();

  Future<void> show(DreameNotification notification, {String? vacuumName});
}

const _backgroundChannelId = 'scrubby_background_service';
const _backgroundNotificationId = 5100;
const _androidNotificationIcon = 'ic_bg_service_small';
const _notificationHistoryKey = 'notification_history';

Duration notificationDuplicateWindow(DreameNotificationCategory category) =>
    category == DreameNotificationCategory.consumable
    ? const Duration(hours: 24)
    : const Duration(minutes: 2);

bool isDuplicateVacuumNotification(
  DreameNotification notification, {
  required String entityId,
  required DreameNotificationCategory category,
  required String title,
  required String body,
  required DateTime createdAt,
  DateTime? now,
}) {
  if (entityId != notification.entityId ||
      category != notification.category ||
      title != notification.title ||
      body != notification.body) {
    return false;
  }
  return (now ?? DateTime.now()).difference(createdAt).abs() <
      notificationDuplicateWindow(notification.category);
}

bool get _supportsAndroidService =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

Future<void> configureBackgroundNotificationService() async {
  if (!_supportsAndroidService) return;
  talker.info('Configuring Android background notification service');
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
    talker.info('Started background notification service');
  } catch (error, stackTrace) {
    talker.handle(
      error,
      stackTrace,
      'Could not start background notification service',
    );
    // The plugin is intentionally unavailable on desktop and in widget tests.
  }
}

Future<void> stopBackgroundNotificationService() async {
  if (!_supportsAndroidService) return;
  try {
    FlutterBackgroundService().invoke('stop');
    talker.info('Requested background notification service stop');
  } catch (error, stackTrace) {
    talker.handle(
      error,
      stackTrace,
      'Could not stop background notification service',
    );
    // The plugin is intentionally unavailable on desktop and in widget tests.
  }
}

/// Entry point for the Android foreground-service isolate. It reads the same
/// securely stored credentials as the UI isolate and owns a second HA socket
/// only while the app is backgrounded.
@pragma('vm:entry-point')
Future<void> _backgroundServiceEntrypoint(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  installTalkerErrorHandlers();
  talker.info('Background notification service started');
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
    talker.info('Background notification service stopped');
  }

  service.on('stop').listen((_) => stop());
  const storage = FlutterSecureStorage();
  final credentials = await storage.readAll();
  final url = credentials['home_assistant_url'];
  final token = credentials['home_assistant_token'];
  if (url == null || token == null || url.isEmpty || token.isEmpty) {
    talker.warning(
      'Background service stopped: no saved Home Assistant session',
    );
    await stop();
    return;
  }

  try {
    client = HomeAssistantClient(url, token);
    await client.connect();
    final vacuums = await client.fetchVacuums();
    talker.info(
      'Background service connected; monitoring ${vacuums.length} vacuums',
    );
    final names = {for (final vacuum in vacuums) vacuum.entityId: vacuum.name};
    var notificationQueue = Future<void>.value();
    notifications = client.notificationUpdates.listen((notification) {
      talker.info('Received ${notification.category.name} vacuum notification');
      notificationQueue = notificationQueue.then((_) async {
        try {
          final shouldNotify = await _recordBackgroundNotification(
            storage,
            notification,
          );
          if (!shouldNotify) return;
          await LocalVacuumNotificationPresenter.instance.show(
            notification,
            vacuumName: names[notification.entityId],
          );
        } catch (error, stackTrace) {
          talker.handle(
            error,
            stackTrace,
            'Could not process background vacuum notification',
          );
        }
      });
    });
  } catch (error, stackTrace) {
    talker.handle(error, stackTrace, 'Background notification service failed');
    await stop();
  }
}

Future<bool> _recordBackgroundNotification(
  FlutterSecureStorage storage,
  DreameNotification notification,
) async {
  try {
    final now = DateTime.now();
    final saved =
        jsonDecode(await storage.read(key: _notificationHistoryKey) ?? '[]')
            as List<dynamic>;
    final records = saved.whereType<Map<String, dynamic>>().toList();
    final duplicate = records.any((record) {
      final recordedAt = DateTime.tryParse(
        record['created_at']?.toString() ?? '',
      );
      if (recordedAt == null) return false;
      final category = DreameNotificationCategory.values.firstWhere(
        (value) => value.name == record['category'],
        orElse: () => DreameNotificationCategory.information,
      );
      return isDuplicateVacuumNotification(
        notification,
        entityId: record['entity_id']?.toString() ?? '',
        category: category,
        title: record['title']?.toString() ?? '',
        body: record['body']?.toString() ?? '',
        createdAt: recordedAt,
        now: now,
      );
    });
    if (duplicate) return false;
    records.insert(0, {
      'category': notification.category.name,
      'entity_id': notification.entityId,
      'title': notification.title,
      'body': notification.body,
      'created_at': now.toIso8601String(),
    });
    await storage.write(
      key: _notificationHistoryKey,
      value: jsonEncode(records.take(30).toList()),
    );
    return true;
  } catch (error, stackTrace) {
    talker.handle(
      error,
      stackTrace,
      'Could not save background notification history',
    );
    // A history write must never prevent the native alert from being posted.
    return true;
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
      talker.info('Local notifications are unavailable on this platform');
      return;
    }
    try {
      // flutter_local_notifications resolves small icons from res/drawable.
      // The launcher icon lives in res/mipmap and makes initialization fail,
      // which would otherwise silently disable every event notification.
      const android = AndroidInitializationSettings(_androidNotificationIcon);
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
    } catch (error, stackTrace) {
      // A notification plugin failure must never prevent Home Assistant login.
      talker.handle(
        error,
        stackTrace,
        'Could not initialize local notifications',
      );
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
    talker.debug('Showing ${notification.category.name} vacuum notification');
    final channel = notification.category;
    final androidChannel = _androidChannels.firstWhere(
      (item) => item.id == channel.channelId,
    );
    final titlePrefix = vacuumName?.trim();
    final title = titlePrefix == null || titlePrefix.isEmpty
        ? notification.title
        : '$titlePrefix · ${notification.title}';
    await _plugin.show(
      // The UI and Android foreground-service isolates can overlap briefly
      // while the app is changing lifecycle state.  A stable ID means that an
      // event received by both replaces the first native notification instead
      // of showing it twice.
      id: _notificationId(notification),
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
          onlyAlertOnce: true,
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

  int _notificationId(DreameNotification notification) {
    final value = [
      notification.category.name,
      notification.entityId,
      notification.title,
      notification.body,
      notification.code,
    ].join('\u0000');
    var hash = 0x811c9dc5;
    for (final codeUnit in value.codeUnits) {
      hash = (hash ^ codeUnit) * 0x01000193 & 0x7fffffff;
    }
    return hash;
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
