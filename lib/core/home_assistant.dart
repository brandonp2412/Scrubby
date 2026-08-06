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
  });

  final String entityId;
  final String name;
  final String state;
  final int? battery;
  final String? fanSpeed;
  final List<String> fanSpeeds;
  final Uint8List? mapImage;

  bool get isCleaning => state == 'cleaning';
  bool get isPaused => state == 'paused';
  bool get isDocked => state == 'docked' || state == 'idle';

  VacuumEntity copyWith({String? state, int? battery, String? fanSpeed}) {
    return VacuumEntity(
      entityId: entityId,
      name: name,
      state: state ?? this.state,
      battery: battery ?? this.battery,
      fanSpeed: fanSpeed ?? this.fanSpeed,
      fanSpeeds: fanSpeeds,
      mapImage: mapImage,
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
    );
  }
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
  });

  final String id;
  final String entityId;
  final String title;
  final String time;
  final List<int> weekdays;
  final String vacuumEntityId;
  final bool enabled;
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
  final Map<String, Map<String, dynamic>> _states = {};
  final Map<String, Uint8List> _mapImages = {};
  final Map<String, String> _mapEntityIds = {};
  final Map<String, Timer> _mapRefreshTimers = {};
  final Map<String, int> _mapRefreshVersions = {};
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _socketSubscription;
  Timer? _reconnectTimer;
  bool _closed = false;
  bool _isConnecting = false;
  int _connectionGeneration = 0;
  String _locationName = 'Home';

  Stream<List<VacuumEntity>> get vacuumUpdates => _vacuumUpdates.stream;

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
                channel.sink.add(
                  jsonEncode({
                    'id': 3,
                    'type': 'subscribe_events',
                    'event_type': 'state_changed',
                  }),
                );
              case 'auth_invalid':
                if (!ready.isCompleted) {
                  ready.completeError(
                    Exception('That access token was not accepted.'),
                  );
                }
              case 'result':
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
    final data = event?['data'] as Map<String, dynamic>?;
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
    await _socketSubscription?.cancel();
    await _channel?.sink.close();
    await _vacuumUpdates.close();
    if (_ownsHttpClient) _httpClient.close();
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
  }) async {
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
              {
                'service': 'vacuum.start',
                'target': {'entity_id': vacuumEntityId},
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
    final vacuumAction = actions.whereType<Map<String, dynamic>>().firstWhere(
      (action) =>
          action['service'] == 'vacuum.start' ||
          action['action'] == 'vacuum.start',
      orElse: () => const {},
    );
    final target = vacuumAction['target'] as Map<String, dynamic>? ?? const {};
    final data = vacuumAction['data'] as Map<String, dynamic>? ?? const {};
    final targetEntity = target['entity_id'] ?? data['entity_id'];

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
    );
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
