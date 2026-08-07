import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

class VacuumEntity {
  const VacuumEntity({
    required this.entityId,
    required this.name,
    required this.state,
    required this.battery,
    this.fanSpeed,
    this.fanSpeeds = const [],
    this.mapImage,
    this.supportedFeatures = 0,
  });

  final String entityId;
  final String name;
  final String state;
  final int? battery;
  final String? fanSpeed;
  final List<String> fanSpeeds;
  final Uint8List? mapImage;
  final int supportedFeatures;

  bool get isCleaning => state == 'cleaning';
  bool get isPaused => state == 'paused';
  bool get isDocked => state == 'docked' || state == 'idle';
  bool get supportsAreaCleaning => supportedFeatures & 16384 != 0;

  VacuumEntity copyWith({String? state, int? battery, String? fanSpeed}) {
    return VacuumEntity(
      entityId: entityId,
      name: name,
      state: state ?? this.state,
      battery: battery ?? this.battery,
      fanSpeed: fanSpeed ?? this.fanSpeed,
      fanSpeeds: fanSpeeds,
      mapImage: mapImage,
      supportedFeatures: supportedFeatures,
    );
  }

  factory VacuumEntity.fromJson(Map<String, dynamic> json) {
    final attributes = json['attributes'] as Map<String, dynamic>? ?? {};
    return VacuumEntity(
      entityId: json['entity_id'] as String,
      name: _displayName(attributes['friendly_name']),
      state: json['state'] as String? ?? 'unknown',
      battery: _readBattery(attributes),
      fanSpeed: attributes['fan_speed']?.toString(),
      fanSpeeds: (attributes['fan_speed_list'] as List<dynamic>? ?? const [])
          .map((value) => value.toString())
          .toList(growable: false),
      supportedFeatures:
          (attributes['supported_features'] as num?)?.toInt() ?? 0,
    );
  }
}

class VacuumSegment {
  const VacuumSegment({required this.id, required this.name, this.group});

  final String id;
  final String name;
  final String? group;

  factory VacuumSegment.fromJson(Map<String, dynamic> json) => VacuumSegment(
    id: json['id'].toString(),
    name: json['name']?.toString().trim().isNotEmpty == true
        ? json['name'].toString()
        : 'Room ${json['id']}',
    group: json['group']?.toString(),
  );
}

class SegmentCleaningCapability {
  const SegmentCleaningCapability({
    required this.domain,
    required this.service,
    required this.segmentField,
    this.minimumRepeats = 1,
    this.maximumRepeats = 1,
  });

  final String domain;
  final String service;
  final String segmentField;
  final int minimumRepeats;
  final int maximumRepeats;

  bool get supportsRepeats => maximumRepeats > minimumRepeats;
}

enum DreameNotificationCategory {
  cleanup,
  consumable,
  information,
  warning,
  error,
}

/// A notification emitted by Tasshack's Dreame Home Assistant integration.
///
/// The integration fires five event types on the HA event bus. Keeping the
/// parser here makes the WebSocket boundary explicit and lets the native
/// notification layer remain independent from Home Assistant JSON.
class DreameNotification {
  const DreameNotification({
    required this.category,
    required this.entityId,
    required this.title,
    required this.body,
    this.code,
  });

  static const supportedEventTypes = <String>{
    'dreame_vacuum_task_status',
    'dreame_vacuum_consumable',
    'dreame_vacuum_information',
    'dreame_vacuum_warning',
    'dreame_vacuum_error',
  };

  final DreameNotificationCategory category;
  final String entityId;
  final String title;
  final String body;
  final int? code;

  static DreameNotification? fromHomeAssistantEvent(
    Map<String, dynamic> event,
  ) {
    final eventType = event['event_type']?.toString() ?? '';
    if (!supportedEventTypes.contains(eventType)) return null;
    final data = event['data'] as Map<String, dynamic>? ?? const {};
    final entityId = data['entity_id']?.toString() ?? '';
    final suffix = eventType.substring('dreame_vacuum_'.length);
    return switch (suffix) {
      'task_status' => _taskNotification(entityId, data),
      'consumable' => DreameNotification(
        category: DreameNotificationCategory.consumable,
        entityId: entityId,
        title: 'Maintenance needed',
        body: _consumableMessage(data['consumable']?.toString()),
      ),
      'information' => DreameNotification(
        category: DreameNotificationCategory.information,
        entityId: entityId,
        title: 'Robot information',
        body: _informationMessage(data['information']?.toString()),
      ),
      'warning' => DreameNotification(
        category: DreameNotificationCategory.warning,
        entityId: entityId,
        title: 'Robot warning',
        body: _humanize(data['warning']?.toString() ?? 'Attention required'),
        code: _integer(data['code']),
      ),
      'error' => DreameNotification(
        category: DreameNotificationCategory.error,
        entityId: entityId,
        title: 'Robot error',
        body: _humanize(data['error']?.toString() ?? 'Robot error'),
        code: _integer(data['code']),
      ),
      _ => null,
    };
  }

  static DreameNotification _taskNotification(
    String entityId,
    Map<String, dynamic> data,
  ) {
    final completed = data['completed'] == true;
    final status = _humanize(data['status']?.toString() ?? 'Cleaning');
    if (!completed) {
      return DreameNotification(
        category: DreameNotificationCategory.cleanup,
        entityId: entityId,
        title: 'Cleaning started',
        body: status,
      );
    }
    final details = <String>[];
    final area = data['cleaned_area'];
    final minutes = data['cleaning_time'];
    if (area != null) details.add('$area m²');
    if (minutes != null) details.add('$minutes min');
    return DreameNotification(
      category: DreameNotificationCategory.cleanup,
      entityId: entityId,
      title: 'Cleanup completed',
      body: details.isEmpty ? status : details.join(' · '),
    );
  }

  static String _consumableMessage(String? value) => switch (value) {
    'main_brush' => 'Replace the main brush and reset its counter.',
    'side_brush' => 'Replace the side brush and reset its counter.',
    'filter' ||
    'secondary_filter' => 'Replace the filter and reset its counter.',
    'sensor' => 'Clean the sensors and reset their counter.',
    'mop_pad' => 'Replace the mop pad and reset its counter.',
    'silver_ion' => 'Replace the silver-ion sterilizer and reset its counter.',
    'detergent' => 'Check and replace the floor-cleaning solution.',
    _ => _humanize(value ?? 'A consumable needs attention'),
  };

  static String _informationMessage(String? value) => switch (value) {
    'dust_collection' =>
      'Auto-empty was not performed during the do-not-disturb period.',
    'cleaning_paused' =>
      'Cleaning is paused and will resume after charging or do-not-disturb.',
    _ => _humanize(value ?? 'Robot information'),
  };

  static String _humanize(String value) {
    final withoutMarkdown = value
        .replaceAll(RegExp(r'!\[[^]]*\]\([^)]*\)'), '')
        .replaceAll(RegExp(r'[#*_`]'), '')
        .trim();
    if (withoutMarkdown.isEmpty) return 'Attention required';
    if (withoutMarkdown.contains(' ') || withoutMarkdown.contains('\n')) {
      return withoutMarkdown;
    }
    final words = withoutMarkdown.replaceAll('_', ' ');
    return '${words[0].toUpperCase()}${words.substring(1)}';
  }

  static int? _integer(Object? value) =>
      value is num ? value.toInt() : int.tryParse(value?.toString() ?? '');
}

enum VacuumSettingKind { toggle, select, number, action }

/// A configurable Home Assistant entity belonging to the vacuum's device.
/// Dreame exposes model-specific options (including carpet behaviour) as
/// switch, select, number and button entities, so this stays capability based.
class VacuumSetting {
  const VacuumSetting({
    required this.entityId,
    required this.name,
    required this.kind,
    required this.value,
    this.options = const [],
    this.minimum,
    this.maximum,
    this.step,
    this.unit,
    this.available = true,
  });

  final String entityId;
  final String name;
  final VacuumSettingKind kind;
  final String value;
  final List<String> options;
  final double? minimum;
  final double? maximum;
  final double? step;
  final String? unit;
  final bool available;

  bool get enabled => value == 'on';

  String get category {
    final searchable = '$entityId $name'.toLowerCase();
    if (searchable.contains('carpet') || searchable.contains('rug')) {
      return 'Carpets';
    }
    if (RegExp(r'mop|water|wash|dry|detergent').hasMatch(searchable)) {
      return 'Mopping';
    }
    if (RegExp(r'dock|empty|base|charging').hasMatch(searchable)) {
      return 'Dock';
    }
    if (RegExp(r'brush|filter|sensor|maintenance|reset').hasMatch(searchable)) {
      return 'Care & maintenance';
    }
    if (RegExp(
      r'clean|suction|route|obstacle|collision|edge|boost',
    ).hasMatch(searchable)) {
      return 'Cleaning';
    }
    return 'Robot preferences';
  }

  VacuumSetting copyWithValue(String newValue) => VacuumSetting(
    entityId: entityId,
    name: name,
    kind: kind,
    value: newValue,
    options: options,
    minimum: minimum,
    maximum: maximum,
    step: step,
    unit: unit,
    available: available,
  );
}

class HomeAssistantSchedule {
  const HomeAssistantSchedule({
    required this.id,
    required this.entityId,
    required this.title,
    required this.time,
    required this.weekdays,
    required this.vacuumEntityId,
    required this.enabled,
    this.fanSpeed,
    this.settings = const [],
    this.segmentIds = const [],
    this.cycles = 1,
  });

  final String id;
  final String entityId;
  final String title;
  final String time;
  final List<int> weekdays;
  final String vacuumEntityId;
  final bool enabled;
  final String? fanSpeed;
  final List<VacuumSetting> settings;
  final List<String> segmentIds;
  final int cycles;
}

String _displayName(Object? friendlyName) {
  final name = friendlyName?.toString().trim() ?? '';
  if (name.isEmpty) return 'Robot vacuum';

  final words = name.split(RegExp(r'\s+'));
  if (words.length.isEven) {
    final midpoint = words.length ~/ 2;
    final firstHalf = words.take(midpoint).join(' ');
    final secondHalf = words.skip(midpoint).join(' ');
    if (firstHalf == secondHalf) return firstHalf;
  }

  return name;
}

String _settingDisplayName(String entityId) {
  final slug = entityId.split('.').last.replaceAll('_', ' ');
  return slug.isEmpty
      ? 'Robot setting'
      : '${slug[0].toUpperCase()}${slug.substring(1)}';
}

int? _readBattery(Map<String, dynamic> attributes) {
  for (final key in const [
    'battery_level',
    'battery',
    'battery_percentage',
    'battery_percent',
  ]) {
    final value = _percentage(attributes[key]);
    if (value != null) return value;
  }
  return null;
}

int? _percentage(Object? value) {
  final number = value is num
      ? value.toDouble()
      : double.tryParse(value?.toString().replaceAll('%', '').trim() ?? '');
  if (number == null || !number.isFinite || number < 0 || number > 100) {
    return null;
  }
  return number.round();
}

class HomeAssistantClient {
  HomeAssistantClient(String url, this.token, {http.Client? httpClient})
    : baseUrl = url.trim().replaceFirst(RegExp(r'/$'), ''),
      _httpClient = httpClient ?? http.Client(),
      _ownsHttpClient = httpClient == null;

  final String baseUrl;
  final String token;
  final http.Client _httpClient;
  final bool _ownsHttpClient;
  final _vacuumUpdates = StreamController<List<VacuumEntity>>.broadcast();
  final _notificationUpdates = StreamController<DreameNotification>.broadcast();
  final Map<String, Map<String, dynamic>> _states = {};
  final Map<String, Uint8List> _mapImages = {};
  final Map<String, String> _mapEntityIds = {};
  final Map<String, Timer> _mapRefreshTimers = {};
  final Map<String, int> _mapRefreshVersions = {};
  final Map<int, Completer<Object?>> _pendingCommands = {};
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _socketSubscription;
  Timer? _reconnectTimer;
  bool _closed = false;
  bool _isConnecting = false;
  int _connectionGeneration = 0;
  int _nextCommandId = 9;
  String _locationName = 'Home';

  Stream<List<VacuumEntity>> get vacuumUpdates => _vacuumUpdates.stream;
  Stream<DreameNotification> get notificationUpdates =>
      _notificationUpdates.stream;

  Map<String, String> get _headers => {
    'Authorization': 'Bearer $token',
    'Content-Type': 'application/json',
  };

  static const _scrubbyAutomationPrefix = 'scrubby_';
  static const _scrubbyAutomationDescription =
      'Managed by Scrubby. Edit this schedule in the Scrubby app.';

  Future<String> connect() async {
    await _openSocket(isInitialConnection: true).timeout(
      const Duration(seconds: 12),
      onTimeout: () =>
          throw Exception('Timed out while connecting to Home Assistant.'),
    );
    return _locationName;
  }

  Future<List<VacuumEntity>> fetchVacuums() async {
    final states = _states.values.toList(growable: false);
    final vacuumStates = states.where(
      (item) => (item['entity_id'] as String? ?? '').startsWith('vacuum.'),
    );
    final vacuums = <VacuumEntity>[];
    for (final state in vacuumStates) {
      var vacuum = VacuumEntity.fromJson(state);
      final battery = vacuum.battery ?? _findBattery(state, states);
      final mapEntity = _findMapEntity(state, states);
      final mapEntityId = mapEntity?['entity_id'] as String?;
      if (mapEntityId != null) _mapEntityIds[vacuum.entityId] = mapEntityId;
      final mapImage = mapEntity == null ? null : await _fetchMap(mapEntity);
      if (mapImage != null) _mapImages[vacuum.entityId] = mapImage;
      vacuum = VacuumEntity(
        entityId: vacuum.entityId,
        name: vacuum.name,
        state: vacuum.state,
        battery: battery,
        fanSpeed: vacuum.fanSpeed,
        fanSpeeds: vacuum.fanSpeeds,
        mapImage: mapImage,
        supportedFeatures: vacuum.supportedFeatures,
      );
      vacuums.add(vacuum);
    }
    return vacuums;
  }

  Uri get _webSocketUri {
    final uri = Uri.parse(baseUrl);
    return uri.replace(
      scheme: uri.scheme == 'https' ? 'wss' : 'ws',
      path: '${uri.path.replaceFirst(RegExp(r'/$'), '')}/api/websocket',
      query: null,
      fragment: null,
    );
  }

  Future<void> _openSocket({required bool isInitialConnection}) async {
    if (_closed || _isConnecting) return;
    _isConnecting = true;
    _reconnectTimer?.cancel();
    final generation = ++_connectionGeneration;
    final ready = Completer<void>();
    var hasConfig = false;
    var hasStates = false;

    void completeWhenReady() {
      if (hasConfig && hasStates && !ready.isCompleted) ready.complete();
    }

    try {
      final channel = WebSocketChannel.connect(_webSocketUri);
      _channel = channel;
      await channel.ready;
      _socketSubscription = channel.stream.listen(
        (message) {
          if (_closed || generation != _connectionGeneration) return;
          try {
            final data = jsonDecode(message as String) as Map<String, dynamic>;
            switch (data['type']) {
              case 'auth_required':
                channel.sink.add(
                  jsonEncode({'type': 'auth', 'access_token': token}),
                );
              case 'auth_ok':
                channel.sink.add(jsonEncode({'id': 1, 'type': 'get_config'}));
                channel.sink.add(jsonEncode({'id': 2, 'type': 'get_states'}));
                final eventTypes = <String>[
                  'state_changed',
                  ...DreameNotification.supportedEventTypes,
                ];
                for (var index = 0; index < eventTypes.length; index++) {
                  channel.sink.add(
                    jsonEncode({
                      'id': index + 3,
                      'type': 'subscribe_events',
                      'event_type': eventTypes[index],
                    }),
                  );
                }
              case 'auth_invalid':
                if (!ready.isCompleted) {
                  ready.completeError(
                    Exception('That access token was not accepted.'),
                  );
                }
              case 'result':
                final commandId = data['id'] as int?;
                final pending = commandId == null
                    ? null
                    : _pendingCommands.remove(commandId);
                if (pending != null) {
                  if (data['success'] == true) {
                    pending.complete(data['result']);
                  } else {
                    final error =
                        data['error'] as Map<String, dynamic>? ?? const {};
                    pending.completeError(
                      Exception(
                        error['message']?.toString() ??
                            'Home Assistant rejected the request.',
                      ),
                    );
                  }
                  return;
                }
                if (data['success'] != true) {
                  if (!ready.isCompleted) {
                    ready.completeError(
                      Exception('Home Assistant rejected a WebSocket request.'),
                    );
                  }
                  return;
                }
                if (data['id'] == 1) {
                  final result = data['result'] as Map<String, dynamic>? ?? {};
                  _locationName = result['location_name'] as String? ?? 'Home';
                  hasConfig = true;
                  completeWhenReady();
                } else if (data['id'] == 2) {
                  final states = data['result'] as List<dynamic>? ?? const [];
                  _replaceStates(states);
                  hasStates = true;
                  completeWhenReady();
                  if (!isInitialConnection) {
                    _emitVacuumUpdate();
                    _scheduleAllMapRefreshes();
                  }
                }
              case 'event':
                _handleEvent(data);
            }
          } catch (error, stackTrace) {
            if (!ready.isCompleted) ready.completeError(error, stackTrace);
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          if (!ready.isCompleted) ready.completeError(error, stackTrace);
          _handleDisconnect(generation);
        },
        onDone: () {
          if (!ready.isCompleted) {
            ready.completeError(
              Exception('Home Assistant closed the WebSocket connection.'),
            );
          }
          _handleDisconnect(generation);
        },
        cancelOnError: true,
      );
      await ready.future;
    } catch (error) {
      if (isInitialConnection) rethrow;
      _scheduleReconnect();
    } finally {
      _isConnecting = false;
    }
  }

  void _replaceStates(List<dynamic> states) {
    _states.clear();
    for (final item in states) {
      if (item is Map<String, dynamic>) {
        final entityId = item['entity_id'] as String?;
        if (entityId != null) _states[entityId] = item;
      }
    }
  }

  void _handleEvent(Map<String, dynamic> message) {
    final event = message['event'] as Map<String, dynamic>?;
    if (event == null) return;
    final notification = DreameNotification.fromHomeAssistantEvent(event);
    if (notification != null) {
      _notificationUpdates.add(notification);
      return;
    }
    if (event['event_type'] != 'state_changed') return;
    final data = event['data'] as Map<String, dynamic>?;
    final entityId = data?['entity_id'] as String?;
    if (entityId == null) return;
    final oldState = _states[entityId];
    final newState = data?['new_state'];
    if (newState is Map<String, dynamic>) {
      _states[entityId] = newState;
    } else {
      _states.remove(entityId);
    }
    if (entityId.startsWith('vacuum.') ||
        _isBatteryState(oldState) ||
        _isBatteryState(newState)) {
      _emitVacuumUpdate();
    }
    if (entityId.startsWith('camera.') || entityId.startsWith('image.')) {
      _scheduleAffectedMapRefreshes(entityId);
    }
  }

  bool _isBatteryState(Object? state) {
    if (state is! Map<String, dynamic>) return false;
    final entityId = state['entity_id']?.toString().toLowerCase() ?? '';
    final attributes = state['attributes'] as Map<String, dynamic>? ?? const {};
    return entityId.startsWith('sensor.') &&
        (attributes['device_class'] == 'battery' ||
            entityId.contains('battery'));
  }

  void _emitVacuumUpdate() {
    if (_closed) return;
    final states = _states.values.toList(growable: false);
    final vacuums = states
        .where(
          (item) => (item['entity_id'] as String? ?? '').startsWith('vacuum.'),
        )
        .map((state) {
          final parsed = VacuumEntity.fromJson(state);
          return VacuumEntity(
            entityId: parsed.entityId,
            name: parsed.name,
            state: parsed.state,
            battery: parsed.battery ?? _findBattery(state, states),
            fanSpeed: parsed.fanSpeed,
            fanSpeeds: parsed.fanSpeeds,
            mapImage: _mapImages[parsed.entityId],
            supportedFeatures: parsed.supportedFeatures,
          );
        })
        .toList(growable: false);
    _vacuumUpdates.add(vacuums);
  }

  void _scheduleAllMapRefreshes() {
    for (final entityId in _states.keys) {
      if (entityId.startsWith('vacuum.')) _scheduleMapRefresh(entityId);
    }
  }

  void _scheduleAffectedMapRefreshes(String changedMapEntityId) {
    final states = _states.values.toList(growable: false);
    for (final vacuumState in states.where(
      (item) => (item['entity_id'] as String? ?? '').startsWith('vacuum.'),
    )) {
      final vacuumId = vacuumState['entity_id'] as String;
      final currentMap = _findMapEntity(vacuumState, states);
      final currentMapId = currentMap?['entity_id'] as String?;
      if (_mapEntityIds[vacuumId] == changedMapEntityId ||
          currentMapId == changedMapEntityId) {
        _scheduleMapRefresh(vacuumId);
      }
    }
  }

  void _scheduleMapRefresh(String vacuumId) {
    _mapRefreshTimers[vacuumId]?.cancel();
    final version = (_mapRefreshVersions[vacuumId] ?? 0) + 1;
    _mapRefreshVersions[vacuumId] = version;
    _mapRefreshTimers[vacuumId] = Timer(
      const Duration(milliseconds: 350),
      () => _refreshMap(vacuumId, version),
    );
  }

  Future<void> _refreshMap(String vacuumId, int version) async {
    if (_closed) return;
    final states = _states.values.toList(growable: false);
    final vacuumState = _states[vacuumId];
    if (vacuumState == null) return;
    final mapEntity = _findMapEntity(vacuumState, states);
    if (mapEntity == null) {
      _mapEntityIds.remove(vacuumId);
      if (_mapImages.remove(vacuumId) != null) _emitVacuumUpdate();
      return;
    }
    final mapEntityId = mapEntity['entity_id'] as String;
    _mapEntityIds[vacuumId] = mapEntityId;
    final image = await _fetchMap(mapEntity, avoidCache: true);
    if (_closed || _mapRefreshVersions[vacuumId] != version || image == null) {
      return;
    }
    _mapImages[vacuumId] = image;
    _emitVacuumUpdate();
  }

  void _handleDisconnect(int generation) {
    if (_closed || generation != _connectionGeneration) return;
    _failPendingCommands(
      Exception('The Home Assistant connection was interrupted.'),
    );
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_closed || _reconnectTimer?.isActive == true) return;
    _reconnectTimer = Timer(
      const Duration(seconds: 3),
      () => _openSocket(isInitialConnection: false),
    );
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _reconnectTimer?.cancel();
    for (final timer in _mapRefreshTimers.values) {
      timer.cancel();
    }
    _mapRefreshTimers.clear();
    _failPendingCommands(Exception('The Home Assistant connection closed.'));
    await _socketSubscription?.cancel();
    await _channel?.sink.close();
    await _vacuumUpdates.close();
    await _notificationUpdates.close();
    if (_ownsHttpClient) _httpClient.close();
  }

  void _failPendingCommands(Object error) {
    final pending = _pendingCommands.values.toList(growable: false);
    _pendingCommands.clear();
    for (final command in pending) {
      command.completeError(error);
    }
  }

  Future<Object?> _sendSocketCommand(Map<String, Object?> command) async {
    final channel = _channel;
    if (_closed || channel == null) {
      throw Exception('Home Assistant is not connected.');
    }
    final id = _nextCommandId++;
    final completer = Completer<Object?>();
    _pendingCommands[id] = completer;
    try {
      channel.sink.add(jsonEncode({'id': id, ...command}));
      return await completer.future.timeout(const Duration(seconds: 12));
    } finally {
      _pendingCommands.remove(id);
    }
  }

  Future<List<VacuumSegment>> fetchVacuumSegments(String entityId) async {
    final result = await _sendSocketCommand({
      'type': 'vacuum/get_segments',
      'entity_id': entityId,
    });
    final data = result as Map<String, dynamic>? ?? const {};
    final segments = data['segments'] as List<dynamic>? ?? const [];
    return segments
        .whereType<Map<String, dynamic>>()
        .map(VacuumSegment.fromJson)
        .toList(growable: false);
  }

  Future<List<VacuumSetting>> fetchVacuumSettings(String vacuumEntityId) async {
    final registryResult = await _sendSocketCommand({
      'type': 'config/entity_registry/list',
    });
    final registry = (registryResult as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
    final vacuumEntry = registry.where(
      (entry) => entry['entity_id'] == vacuumEntityId,
    );
    if (vacuumEntry.isEmpty) return const [];
    final deviceId = vacuumEntry.first['device_id']?.toString();
    if (deviceId == null || deviceId.isEmpty) return const [];

    const supportedDomains = {'switch', 'select', 'number', 'button'};
    final settings = <VacuumSetting>[];
    for (final entry in registry) {
      if (entry['device_id']?.toString() != deviceId ||
          entry['disabled_by'] != null ||
          entry['hidden_by'] != null) {
        continue;
      }
      final entityId = entry['entity_id']?.toString() ?? '';
      final domain = entityId.split('.').first;
      if (!supportedDomains.contains(domain)) continue;
      final state = _states[entityId];
      if (state == null) continue;
      final attributes =
          state['attributes'] as Map<String, dynamic>? ?? const {};
      final rawName = entry['name']?.toString().trim().isNotEmpty == true
          ? entry['name'].toString()
          : attributes['friendly_name']?.toString() ??
                entry['original_name']?.toString() ??
                entityId.split('.').last.replaceAll('_', ' ');
      final name = _settingName(rawName, vacuumEntityId);
      final kind = switch (domain) {
        'switch' => VacuumSettingKind.toggle,
        'select' => VacuumSettingKind.select,
        'number' => VacuumSettingKind.number,
        _ => VacuumSettingKind.action,
      };
      settings.add(
        VacuumSetting(
          entityId: entityId,
          name: name,
          kind: kind,
          value: state['state']?.toString() ?? 'unknown',
          options: (attributes['options'] as List<dynamic>? ?? const [])
              .map((option) => option.toString())
              .toList(growable: false),
          minimum: (attributes['min'] as num?)?.toDouble(),
          maximum: (attributes['max'] as num?)?.toDouble(),
          step: (attributes['step'] as num?)?.toDouble(),
          unit: attributes['unit_of_measurement']?.toString(),
          available:
              state['state'] != 'unavailable' && state['state'] != 'unknown',
        ),
      );
    }
    const categoryOrder = [
      'Carpets',
      'Cleaning',
      'Mopping',
      'Dock',
      'Care & maintenance',
      'Robot preferences',
    ];
    settings.sort((a, b) {
      final category = categoryOrder
          .indexOf(a.category)
          .compareTo(categoryOrder.indexOf(b.category));
      return category != 0 ? category : a.name.compareTo(b.name);
    });
    return settings;
  }

  Future<SegmentCleaningCapability?> fetchSegmentCleaningCapability() async {
    final response = await _httpClient
        .get(Uri.parse('$baseUrl/api/services'), headers: _headers)
        .timeout(const Duration(seconds: 12));
    _requireSuccess(response, 'discover room-cleaning services');
    final domains = jsonDecode(response.body) as List<dynamic>;
    final candidates = <SegmentCleaningCapability>[];
    for (final domainData in domains.whereType<Map<String, dynamic>>()) {
      final domain = domainData['domain']?.toString() ?? '';
      final services =
          domainData['services'] as Map<String, dynamic>? ?? const {};
      for (final entry in services.entries) {
        if (!entry.key.toLowerCase().contains('clean_segment')) continue;
        final definition = entry.value as Map<String, dynamic>? ?? const {};
        final fields =
            definition['fields'] as Map<String, dynamic>? ?? const {};
        final segmentField = const [
          'segment_ids',
          'segments',
          'segment_id',
        ].where(fields.containsKey).firstOrNull;
        if (segmentField == null) continue;
        final repeatDefinition =
            fields['repeats'] as Map<String, dynamic>? ?? const {};
        final selector =
            repeatDefinition['selector'] as Map<String, dynamic>? ?? const {};
        final number = selector['number'] as Map<String, dynamic>? ?? const {};
        candidates.add(
          SegmentCleaningCapability(
            domain: domain,
            service: entry.key,
            segmentField: segmentField,
            minimumRepeats: (number['min'] as num?)?.toInt() ?? 1,
            maximumRepeats: (number['max'] as num?)?.toInt() ?? 1,
          ),
        );
      }
    }
    candidates.sort((a, b) {
      int score(SegmentCleaningCapability item) {
        if (item.domain == 'dreame_vacuum') return 0;
        if (item.domain == 'vacuum') return 1;
        return 2;
      }

      return score(a).compareTo(score(b));
    });
    return candidates.firstOrNull;
  }

  String _settingName(String rawName, String vacuumEntityId) {
    var name = rawName.trim();
    final vacuumName = _states[vacuumEntityId]?['attributes']?['friendly_name']
        ?.toString()
        .trim();
    if (vacuumName != null &&
        name.toLowerCase().startsWith('${vacuumName.toLowerCase()} ')) {
      name = name.substring(vacuumName.length).trim();
    }
    return name.isEmpty ? rawName : name;
  }

  Future<void> setVacuumSetting(VacuumSetting setting, Object? value) async {
    final domain = setting.entityId.split('.').first;
    switch (setting.kind) {
      case VacuumSettingKind.toggle:
        await callService(
          'switch',
          value == true ? 'turn_on' : 'turn_off',
          entityId: setting.entityId,
        );
      case VacuumSettingKind.select:
        await callService(
          'select',
          'select_option',
          entityId: setting.entityId,
          data: {'option': value?.toString()},
        );
      case VacuumSettingKind.number:
        await callService(
          'number',
          'set_value',
          entityId: setting.entityId,
          data: {'value': value},
        );
      case VacuumSettingKind.action:
        await callService(domain, 'press', entityId: setting.entityId);
    }
  }

  int? _findBattery(
    Map<String, dynamic> vacuum,
    List<Map<String, dynamic>> states,
  ) {
    final candidates = states.where((item) {
      final id = item['entity_id']?.toString() ?? '';
      final attributes = item['attributes'] as Map<String, dynamic>? ?? {};
      return id.startsWith('sensor.') &&
          (attributes['device_class'] == 'battery' ||
              id.toLowerCase().contains('battery')) &&
          _percentage(item['state']) != null;
    }).toList();
    candidates.sort(
      (a, b) =>
          _entityMatchScore(b, vacuum).compareTo(_entityMatchScore(a, vacuum)),
    );
    if (candidates.isEmpty) return null;
    final bestScore = _entityMatchScore(candidates.first, vacuum);
    if (bestScore == 0 && candidates.length != 1) return null;
    return _percentage(candidates.first['state']);
  }

  Map<String, dynamic>? _findMapEntity(
    Map<String, dynamic> vacuum,
    List<Map<String, dynamic>> states,
  ) {
    final candidates = states.where((item) {
      final id = item['entity_id']?.toString() ?? '';
      final attributes = item['attributes'] as Map<String, dynamic>? ?? {};
      final searchable = '$id ${attributes['friendly_name'] ?? ''}'
          .toLowerCase();
      return (id.startsWith('camera.') || id.startsWith('image.')) &&
          (searchable.contains('map') || searchable.contains('floor'));
    }).toList();
    candidates.sort(
      (a, b) =>
          _entityMatchScore(b, vacuum).compareTo(_entityMatchScore(a, vacuum)),
    );
    if (candidates.isEmpty) return null;
    if (candidates.length == 1 ||
        _entityMatchScore(candidates.first, vacuum) > 0) {
      return candidates.first;
    }
    return null;
  }

  int _entityMatchScore(
    Map<String, dynamic> candidate,
    Map<String, dynamic> vacuum,
  ) {
    String normalized(Object? value) => value
        .toString()
        .toLowerCase()
        .replaceAll(RegExp(r'^(vacuum|sensor|camera|image)\.'), '')
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim();
    final vacuumAttributes =
        vacuum['attributes'] as Map<String, dynamic>? ?? const {};
    final candidateAttributes =
        candidate['attributes'] as Map<String, dynamic>? ?? const {};
    final needles = {
      normalized(vacuum['entity_id']),
      normalized(vacuumAttributes['friendly_name']),
    }.where((value) => value.length >= 3);
    final haystack =
        '${normalized(candidate['entity_id'])} '
        '${normalized(candidateAttributes['friendly_name'])} '
        '${normalized(candidateAttributes['vacuum_entity'])}';
    return needles.fold(
      0,
      (score, value) => score + (haystack.contains(value) ? 1 : 0),
    );
  }

  Future<Uint8List?> _fetchMap(
    Map<String, dynamic> entity, {
    bool avoidCache = false,
  }) async {
    final entityId = entity['entity_id'] as String;
    final domain = entityId.split('.').first;
    final endpoint = domain == 'camera' ? 'camera_proxy' : 'image_proxy';
    try {
      var uri = Uri.parse('$baseUrl/api/$endpoint/$entityId');
      if (avoidCache) {
        uri = uri.replace(
          queryParameters: {
            '_': DateTime.now().millisecondsSinceEpoch.toString(),
          },
        );
      }
      final response = await _httpClient
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 12));
      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        return response.bodyBytes;
      }
    } catch (_) {
      // A missing or temporarily unavailable map should not prevent login.
    }
    return null;
  }

  Future<void> callVacuumService(
    String service,
    String entityId, {
    Map<String, Object?> data = const {},
  }) async {
    await callService('vacuum', service, entityId: entityId, data: data);
  }

  Future<void> cleanVacuumSegments(
    String entityId,
    List<String> segmentIds,
  ) async {
    if (segmentIds.isEmpty) {
      throw const FormatException('Choose at least one room.');
    }
    final response = await _httpClient
        .get(Uri.parse('$baseUrl/api/services'), headers: _headers)
        .timeout(const Duration(seconds: 12));
    _requireSuccess(response, 'discover room-cleaning services');
    final domains = jsonDecode(response.body) as List<dynamic>;
    final candidates = <({String domain, String service, String field})>[];
    for (final domainData in domains.whereType<Map<String, dynamic>>()) {
      final domain = domainData['domain']?.toString() ?? '';
      final services =
          domainData['services'] as Map<String, dynamic>? ?? const {};
      for (final entry in services.entries) {
        final service = entry.key;
        if (!service.toLowerCase().contains('clean_segment')) continue;
        final definition = entry.value as Map<String, dynamic>? ?? const {};
        final fields =
            definition['fields'] as Map<String, dynamic>? ?? const {};
        final field = const [
          'segment_ids',
          'segments',
          'segment_id',
        ].where(fields.containsKey).firstOrNull;
        if (field != null) {
          candidates.add((domain: domain, service: service, field: field));
        }
      }
    }
    candidates.sort((a, b) {
      int score(({String domain, String service, String field}) item) {
        if (item.domain == 'dreame_vacuum') return 0;
        if (item.domain == 'vacuum') return 1;
        return 2;
      }

      return score(a).compareTo(score(b));
    });

    final rawIds = segmentIds
        .map((id) {
          final raw = id.contains('_') ? id.split('_').last : id;
          return int.tryParse(raw) ?? raw;
        })
        .toList(growable: false);
    Object? lastError;
    for (final candidate in candidates) {
      final ids = candidate.field == 'segment_ids' ? segmentIds : rawIds;
      try {
        await callService(
          candidate.domain,
          candidate.service,
          entityId: entityId,
          data: {candidate.field: ids},
        );
        return;
      } catch (error) {
        lastError = error;
      }
    }
    try {
      final areaIds = await _mappedAreaIds(entityId, segmentIds);
      if (areaIds.isNotEmpty) {
        await callVacuumService(
          'clean_area',
          entityId,
          data: {'cleaning_area_id': areaIds},
        );
        return;
      }
    } catch (error) {
      lastError ??= error;
    }
    if (lastError != null) throw lastError;
    throw Exception(
      'This vacuum reports rooms, but Home Assistant exposes neither a direct segment-cleaning service nor an existing segment-to-area mapping.',
    );
  }

  Future<List<String>> _mappedAreaIds(
    String entityId,
    List<String> segmentIds,
  ) async {
    final result = await _sendSocketCommand({
      'type': 'config/entity_registry/get',
      'entity_id': entityId,
    });
    final entry = result as Map<String, dynamic>? ?? const {};
    final options = entry['options'] as Map<String, dynamic>? ?? const {};
    final vacuumOptions =
        options['vacuum'] as Map<String, dynamic>? ?? const {};
    final mapping =
        vacuumOptions['area_mapping'] as Map<String, dynamic>? ?? const {};
    final requested = segmentIds.toSet();
    final matchedSegments = <String>{};
    final areaIds = <String>[];
    for (final entry in mapping.entries) {
      final mapped = (entry.value as List<dynamic>? ?? const [])
          .map((value) => value.toString())
          .toSet();
      if (mapped.intersection(requested).isEmpty) continue;
      areaIds.add(entry.key);
      matchedSegments.addAll(mapped.intersection(requested));
    }
    return matchedSegments.containsAll(requested) ? areaIds : const [];
  }

  Future<void> callService(
    String domain,
    String service, {
    String? entityId,
    Map<String, Object?> data = const {},
  }) async {
    final response = await _httpClient
        .post(
          Uri.parse('$baseUrl/api/services/$domain/$service'),
          headers: _headers,
          body: jsonEncode({'entity_id': ?entityId, ...data}),
        )
        .timeout(const Duration(seconds: 12));
    _requireSuccess(response, 'run “$domain.$service”');
  }

  Future<List<HomeAssistantSchedule>> fetchScrubbySchedules() async {
    final statesResponse = await _httpClient
        .get(Uri.parse('$baseUrl/api/states'), headers: _headers)
        .timeout(const Duration(seconds: 12));
    _requireSuccess(statesResponse, 'load automations');
    final states = jsonDecode(statesResponse.body) as List<dynamic>;
    final owned = states.whereType<Map<String, dynamic>>().where((state) {
      if (!(state['entity_id']?.toString().startsWith('automation.') ??
          false)) {
        return false;
      }
      final attributes =
          state['attributes'] as Map<String, dynamic>? ?? const {};
      return attributes['id']?.toString().startsWith(
            _scrubbyAutomationPrefix,
          ) ??
          false;
    });

    final schedules = await Future.wait(
      owned.map((state) async {
        final attributes =
            state['attributes'] as Map<String, dynamic>? ?? const {};
        final id = attributes['id'].toString();
        final response = await _httpClient
            .get(
              Uri.parse('$baseUrl/api/config/automation/config/$id'),
              headers: _headers,
            )
            .timeout(const Duration(seconds: 12));
        _requireSuccess(
          response,
          'load schedule “${attributes['friendly_name'] ?? id}”',
        );
        return _parseSchedule(
          id,
          state['entity_id'].toString(),
          state['state'] == 'on',
          jsonDecode(response.body) as Map<String, dynamic>,
        );
      }),
    );
    schedules.sort((a, b) {
      final byTime = a.time.compareTo(b.time);
      return byTime != 0 ? byTime : a.title.compareTo(b.title);
    });
    return schedules;
  }

  Future<void> createScrubbySchedule({
    required String id,
    required String title,
    required String time,
    required List<int> weekdays,
    required String vacuumEntityId,
    String? fanSpeed,
    List<VacuumSetting> settings = const [],
    List<String> segmentIds = const [],
    int cycles = 1,
  }) async {
    final segmentCapability = segmentIds.isEmpty
        ? null
        : await fetchSegmentCleaningCapability();
    if (segmentIds.isNotEmpty && segmentCapability == null) {
      throw Exception(
        'Home Assistant does not expose a segment-cleaning service for this vacuum.',
      );
    }
    final rawSegmentIds = segmentIds
        .map((id) {
          final raw = id.contains('_') ? id.split('_').last : id;
          return int.tryParse(raw) ?? raw;
        })
        .toList(growable: false);
    final supportedCycles = segmentCapability == null
        ? 1
        : cycles.clamp(
            segmentCapability.minimumRepeats,
            segmentCapability.maximumRepeats,
          );
    final response = await _httpClient
        .post(
          Uri.parse('$baseUrl/api/config/automation/config/$id'),
          headers: _headers,
          body: jsonEncode({
            'alias': title,
            'description': _scrubbyAutomationDescription,
            'trigger': [
              {'platform': 'time', 'at': '$time:00'},
            ],
            'condition': [
              {
                'condition': 'time',
                'weekday': weekdays.map(_weekdayCode).toList(),
              },
            ],
            'action': [
              for (final setting in settings.where(_isCleanGeniusSetting))
                _scheduleSettingAction(setting),
              if (fanSpeed != null)
                {
                  'alias': 'Set suction power',
                  'service': 'vacuum.set_fan_speed',
                  'target': {'entity_id': vacuumEntityId},
                  'data': {'fan_speed': fanSpeed},
                },
              for (final setting in settings.where(
                (setting) => !_isCleanGeniusSetting(setting),
              ))
                _scheduleSettingAction(setting),
              if (segmentCapability == null)
                {
                  'service': 'vacuum.start',
                  'target': {'entity_id': vacuumEntityId},
                }
              else
                {
                  'alias': 'Clean selected rooms',
                  'service':
                      '${segmentCapability.domain}.${segmentCapability.service}',
                  'target': {'entity_id': vacuumEntityId},
                  'data': {
                    segmentCapability.segmentField: rawSegmentIds,
                    if (segmentCapability.supportsRepeats)
                      'repeats': supportedCycles,
                  },
                },
            ],
            'mode': 'single',
          }),
        )
        .timeout(const Duration(seconds: 12));
    _requireSuccess(response, 'create the schedule');
    await callService('automation', 'reload');
  }

  Future<void> setScrubbyScheduleEnabled(String entityId, bool enabled) =>
      callService(
        'automation',
        enabled ? 'turn_on' : 'turn_off',
        entityId: entityId,
      );

  Future<void> deleteScrubbySchedule(String id) async {
    final response = await _httpClient
        .delete(
          Uri.parse('$baseUrl/api/config/automation/config/$id'),
          headers: _headers,
        )
        .timeout(const Duration(seconds: 12));
    _requireSuccess(response, 'delete the schedule');
    await callService('automation', 'reload');
  }

  HomeAssistantSchedule _parseSchedule(
    String id,
    String entityId,
    bool enabled,
    Map<String, dynamic> config,
  ) {
    final triggers =
        (config['trigger'] ?? config['triggers']) as List<dynamic>? ?? const [];
    final timeTrigger = triggers.whereType<Map<String, dynamic>>().firstWhere(
      (trigger) =>
          trigger['platform'] == 'time' || trigger['trigger'] == 'time',
      orElse: () => const {},
    );
    final rawTime = timeTrigger['at']?.toString() ?? '00:00';
    final conditions =
        (config['condition'] ?? config['conditions']) as List<dynamic>? ??
        const [];
    final timeCondition = conditions
        .whereType<Map<String, dynamic>>()
        .firstWhere(
          (condition) => condition['condition'] == 'time',
          orElse: () => const {},
        );
    final weekdayValues =
        timeCondition['weekday'] as List<dynamic>? ?? _weekdayCodes;
    final weekdays = weekdayValues
        .map((value) => _weekdayCodes.indexOf(value.toString()) + 1)
        .where((day) => day > 0)
        .toList(growable: false);
    final actions =
        (config['action'] ?? config['actions']) as List<dynamic>? ?? const [];
    final vacuumAction = actions.whereType<Map<String, dynamic>>().firstWhere((
      action,
    ) {
      final service = (action['service'] ?? action['action'])?.toString();
      return service == 'vacuum.start' ||
          (service?.toLowerCase().contains('clean_segment') ?? false);
    }, orElse: () => const {});
    final target = vacuumAction['target'] as Map<String, dynamic>? ?? const {};
    final data = vacuumAction['data'] as Map<String, dynamic>? ?? const {};
    final targetEntity = target['entity_id'] ?? data['entity_id'];
    final segmentValues = const ['segment_ids', 'segments', 'segment_id']
        .map((field) => data[field])
        .firstWhere((value) => value != null, orElse: () => null);
    final segmentIds = switch (segmentValues) {
      List<dynamic> values => values.map((value) => value.toString()).toList(),
      null => const <String>[],
      Object value => <String>[value.toString()],
    };
    final rawRepeats = data['repeats'];
    final cycles = switch (rawRepeats) {
      num value => value.toInt(),
      List<dynamic> values when values.isNotEmpty =>
        int.tryParse(values.first.toString()) ?? 1,
      Object value => int.tryParse(value.toString()) ?? 1,
      _ => 1,
    };

    String? fanSpeed;
    final settings = <VacuumSetting>[];
    for (final action in actions.whereType<Map<String, dynamic>>()) {
      final service = (action['service'] ?? action['action'])?.toString();
      final actionTarget =
          action['target'] as Map<String, dynamic>? ?? const {};
      final actionData = action['data'] as Map<String, dynamic>? ?? const {};
      if (service == 'vacuum.set_fan_speed' &&
          (actionTarget['entity_id'] == targetEntity ||
              actionData['entity_id'] == targetEntity)) {
        fanSpeed = actionData['fan_speed']?.toString();
        continue;
      }
      final setting = _parseScheduleSetting(
        action,
        service,
        actionTarget,
        actionData,
      );
      if (setting != null) settings.add(setting);
    }

    if (timeTrigger.isEmpty || targetEntity == null) {
      throw const FormatException(
        'A Scrubby automation has an invalid configuration.',
      );
    }
    return HomeAssistantSchedule(
      id: id,
      entityId: entityId,
      title: config['alias']?.toString() ?? 'Cleaning',
      time: rawTime.length >= 5 ? rawTime.substring(0, 5) : rawTime,
      weekdays: weekdays.isEmpty
          ? List<int>.generate(7, (index) => index + 1)
          : weekdays,
      vacuumEntityId: targetEntity is List
          ? targetEntity.first.toString()
          : targetEntity.toString(),
      enabled: enabled,
      fanSpeed: fanSpeed,
      settings: settings,
      segmentIds: segmentIds,
      cycles: cycles,
    );
  }

  Map<String, Object?> _scheduleSettingAction(VacuumSetting setting) {
    final target = {'entity_id': setting.entityId};
    return switch (setting.kind) {
      VacuumSettingKind.select => {
        'alias': 'Set ${setting.name}',
        'service': 'select.select_option',
        'target': target,
        'data': {'option': setting.value},
      },
      VacuumSettingKind.number => {
        'alias': 'Set ${setting.name}',
        'service': 'number.set_value',
        'target': target,
        'data': {'value': double.tryParse(setting.value) ?? setting.value},
      },
      VacuumSettingKind.toggle => {
        'alias': 'Set ${setting.name}',
        'service': setting.enabled ? 'switch.turn_on' : 'switch.turn_off',
        'target': target,
      },
      VacuumSettingKind.action => throw ArgumentError(
        'Button actions cannot be added to a cleaning schedule.',
      ),
    };
  }

  bool _isCleanGeniusSetting(VacuumSetting setting) {
    final searchable = '${setting.entityId} ${setting.name}'
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ');
    return (searchable.contains('cleangenius') ||
            searchable.contains('clean genius')) &&
        !searchable.contains('cleangenius mode') &&
        !searchable.contains('clean genius mode');
  }

  VacuumSetting? _parseScheduleSetting(
    Map<String, dynamic> action,
    String? service,
    Map<String, dynamic> target,
    Map<String, dynamic> data,
  ) {
    final entityId = (target['entity_id'] ?? data['entity_id'])?.toString();
    if (entityId == null) return null;
    final alias = action['alias']?.toString();
    final name = alias?.startsWith('Set ') == true
        ? alias!.substring(4)
        : _settingDisplayName(entityId);
    if (service == 'select.select_option' && data['option'] != null) {
      return VacuumSetting(
        entityId: entityId,
        name: name,
        kind: VacuumSettingKind.select,
        value: data['option'].toString(),
      );
    }
    if (service == 'number.set_value' && data['value'] != null) {
      return VacuumSetting(
        entityId: entityId,
        name: name,
        kind: VacuumSettingKind.number,
        value: data['value'].toString(),
      );
    }
    if (service == 'switch.turn_on' || service == 'switch.turn_off') {
      return VacuumSetting(
        entityId: entityId,
        name: name,
        kind: VacuumSettingKind.toggle,
        value: service == 'switch.turn_on' ? 'on' : 'off',
      );
    }
    return null;
  }

  void _requireSuccess(http.Response response, String operation) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw Exception(
        'Your Home Assistant token is not allowed to $operation. An administrator token is required.',
      );
    }
    throw Exception(
      'Home Assistant could not $operation (${response.statusCode}).',
    );
  }
}

const _weekdayCodes = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];

String _weekdayCode(int weekday) {
  if (weekday < DateTime.monday || weekday > DateTime.sunday) {
    throw ArgumentError.value(weekday, 'weekday');
  }
  return _weekdayCodes[weekday - 1];
}
