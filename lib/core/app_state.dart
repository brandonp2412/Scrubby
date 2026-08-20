import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'home_assistant.dart';
import 'notifications.dart';

class CleaningSchedule {
  const CleaningSchedule({
    required this.id,
    required this.entityId,
    required this.title,
    required this.weekdays,
    required this.time,
    required this.vacuumEntityId,
    this.enabled = true,
    this.fanSpeed,
    this.settings = const [],
    this.segmentIds = const [],
    this.cycles = 1,
  });

  final String id;
  final String entityId;
  final String title;
  final List<int> weekdays;
  final String time;
  final String vacuumEntityId;
  final bool enabled;
  final String? fanSpeed;
  final List<VacuumSetting> settings;
  final List<String> segmentIds;
  final int cycles;

  String get days {
    if (weekdays.length == 7) return 'EVERY DAY';
    const names = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    return weekdays.map((day) => names[day - 1]).join(' · ');
  }

  CleaningSchedule copyWith({bool? enabled, String? entityId}) =>
      CleaningSchedule(
        id: id,
        entityId: entityId ?? this.entityId,
        title: title,
        weekdays: weekdays,
        time: time,
        vacuumEntityId: vacuumEntityId,
        enabled: enabled ?? this.enabled,
        fanSpeed: fanSpeed,
        settings: settings,
        segmentIds: segmentIds,
        cycles: cycles,
      );

  factory CleaningSchedule.fromHomeAssistant(HomeAssistantSchedule schedule) =>
      CleaningSchedule(
        id: schedule.id,
        entityId: schedule.entityId,
        title: schedule.title,
        weekdays: schedule.weekdays,
        time: schedule.time,
        vacuumEntityId: schedule.vacuumEntityId,
        enabled: schedule.enabled,
        fanSpeed: schedule.fanSpeed,
        settings: schedule.settings,
        segmentIds: schedule.segmentIds,
        cycles: schedule.cycles,
      );
}

class MapRoomLabel {
  const MapRoomLabel({
    required this.id,
    required this.name,
    required this.segmentId,
  });

  final String id;
  final String name;
  final String segmentId;

  MapRoomLabel copyWith({String? name, String? segmentId}) => MapRoomLabel(
    id: id,
    name: name ?? this.name,
    segmentId: segmentId ?? this.segmentId,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'segment_id': segmentId,
  };

  factory MapRoomLabel.fromJson(Map<String, dynamic> json) => MapRoomLabel(
    id: json['id'] as String,
    name: json['name'] as String,
    segmentId: json['segment_id'].toString(),
  );
}

class VacuumNotificationRecord {
  const VacuumNotificationRecord({
    required this.category,
    required this.entityId,
    required this.title,
    required this.body,
    required this.createdAt,
  });

  final DreameNotificationCategory category;
  final String entityId;
  final String title;
  final String body;
  final DateTime createdAt;

  Map<String, Object> toJson() => {
    'category': category.name,
    'entity_id': entityId,
    'title': title,
    'body': body,
    'created_at': createdAt.toIso8601String(),
  };

  factory VacuumNotificationRecord.fromJson(Map<String, dynamic> json) {
    final category = DreameNotificationCategory.values.firstWhere(
      (value) => value.name == json['category'],
      orElse: () => DreameNotificationCategory.information,
    );
    return VacuumNotificationRecord(
      category: category,
      entityId: json['entity_id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Robot information',
      body: json['body']?.toString() ?? '',
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

class AppState extends ChangeNotifier {
  AppState({
    FlutterSecureStorage? secureStorage,
    VacuumNotificationPresenter? notificationPresenter,
  }) : _secureStorage = secureStorage ?? const FlutterSecureStorage(),
       _notificationPresenter =
           notificationPresenter ?? LocalVacuumNotificationPresenter.instance;

  static const _urlKey = 'home_assistant_url';
  static const _tokenKey = 'home_assistant_token';
  static const _roomLabelsKey = 'map_room_labels';
  static const _vacuumNamesKey = 'vacuum_display_names';
  static const _scheduleOrderKey = 'schedule_order';
  static const _notificationHistoryKey = 'notification_history';
  final FlutterSecureStorage _secureStorage;
  final VacuumNotificationPresenter _notificationPresenter;
  HomeAssistantClient? _client;
  StreamSubscription<List<VacuumEntity>>? _vacuumSubscription;
  StreamSubscription<DreameNotification>? _notificationSubscription;
  StreamSubscription<HomeAssistantConnectionStatus>? _connectionSubscription;
  List<VacuumEntity> vacuums = [];
  int selectedVacuum = 0;
  String homeName = 'Home';
  bool isDemo = false;
  HomeAssistantConnectionStatus connectionStatus =
      HomeAssistantConnectionStatus.connected;
  bool get isOffline =>
      !isDemo && connectionStatus == HomeAssistantConnectionStatus.offline;
  bool isBusy = false;
  bool isInitialized = false;
  String? savedUrl;
  String? restoreError;
  final Map<String, List<MapRoomLabel>> _mapRoomLabels = {};
  final Map<String, String> _vacuumNames = {};
  final Map<String, List<VacuumSegment>> _vacuumSegments = {};
  final Map<String, List<VacuumSetting>> _vacuumSettings = {};
  final Map<String, SegmentCleaningCapability> _segmentCleaningCapabilities =
      {};
  String? roomCapabilityError;
  bool settingsLoading = false;
  String? settingsError;
  final Set<String> busySettingIds = {};
  final List<VacuumNotificationRecord> notificationHistory = [];

  final List<CleaningSchedule> schedules = [];
  bool schedulesLoading = false;
  String? scheduleError;
  final Set<String> busyScheduleIds = {};

  VacuumEntity get vacuum => vacuums[selectedVacuum];
  List<MapRoomLabel> get mapRoomLabels =>
      _mapRoomLabels.putIfAbsent(vacuum.entityId, () => []);
  List<VacuumSegment> get vacuumSegments =>
      _vacuumSegments[vacuum.entityId] ?? const [];
  List<VacuumSetting> get vacuumSettings =>
      _vacuumSettings[vacuum.entityId] ?? const [];
  List<VacuumSetting> settingsForVacuum(String entityId) =>
      _vacuumSettings[entityId] ?? const [];
  SegmentCleaningCapability? segmentCleaningCapabilityFor(String entityId) =>
      _segmentCleaningCapabilities[entityId];
  List<VacuumSegment> segmentsForVacuum(String entityId) =>
      _vacuumSegments[entityId] ?? const [];
  String segmentNameFor(String entityId, VacuumSegment segment) {
    final labels = _mapRoomLabels[entityId] ?? const [];
    final match = labels.where((label) => label.segmentId == segment.id);
    return match.isEmpty ? segment.name : match.first.name;
  }

  String scheduleRooms(CleaningSchedule schedule) {
    if (schedule.segmentIds.isEmpty) return 'Whole home';
    final labelsBySegment = {
      for (final label in _mapRoomLabels[schedule.vacuumEntityId] ?? const [])
        if (label.segmentId != null) label.segmentId!: label.name,
    };
    final segmentsById = {
      for (final segment
          in _vacuumSegments[schedule.vacuumEntityId] ?? const [])
        segment.id: segment.name,
    };
    final names = schedule.segmentIds
        .map((id) => labelsBySegment[id] ?? segmentsById[id] ?? 'Room $id')
        .toList(growable: false);
    if (names.length <= 2) return names.join(', ');
    return '${names.take(2).join(', ')} +${names.length - 2}';
  }

  Future<void> initialize() async {
    try {
      final credentials = await _secureStorage.readAll();
      savedUrl = credentials[_urlKey];
      final token = credentials[_tokenKey];
      _restoreRoomLabels(credentials[_roomLabelsKey]);
      _restoreVacuumNames(credentials[_vacuumNamesKey]);
      _restoreNotificationHistory(credentials[_notificationHistoryKey]);
      if (savedUrl != null && token != null) {
        await login(savedUrl!, token, persist: false);
      }
    } catch (error) {
      restoreError =
          'Could not restore the saved connection. Please reconnect.';
    } finally {
      isInitialized = true;
      notifyListeners();
    }
  }

  Future<void> login(String url, String token, {bool persist = true}) async {
    final client = HomeAssistantClient(url, token.trim());
    try {
      final location = await client.connect();
      final entities = await client.fetchVacuums();
      if (entities.isEmpty) {
        throw Exception('Connected, but no vacuum entities were found.');
      }
      if (persist) {
        await _secureStorage.write(key: _urlKey, value: client.baseUrl);
        await _secureStorage.write(key: _tokenKey, value: token.trim());
      }
      await _vacuumSubscription?.cancel();
      await _notificationSubscription?.cancel();
      await _connectionSubscription?.cancel();
      await _client?.close();
      _client = client;
      _vacuumSubscription = client.vacuumUpdates.listen(_applyVacuumUpdate);
      _notificationSubscription = client.notificationUpdates.listen(
        _showNotification,
      );
      _connectionSubscription = client.connectionUpdates.listen(
        _updateConnectionStatus,
      );
      connectionStatus = client.connectionStatus;
      homeName = location;
      vacuums = entities.map(_withDisplayName).toList(growable: false);
      selectedVacuum = 0;
      isDemo = false;
      savedUrl = client.baseUrl;
      restoreError = null;
      await _loadVacuumSegments();
      await refreshVacuumSettings();
      notifyListeners();
      unawaited(_notificationPresenter.requestPermissions());
      await refreshSchedules();
    } catch (_) {
      await client.close();
      rethrow;
    }
  }

  void _applyVacuumUpdate(List<VacuumEntity> updated) {
    if (updated.isEmpty) return;
    final selectedId = vacuums.isEmpty ? null : vacuum.entityId;
    vacuums = updated.map(_withDisplayName).toList(growable: false);
    final matchingIndex = selectedId == null
        ? -1
        : vacuums.indexWhere((item) => item.entityId == selectedId);
    selectedVacuum = matchingIndex >= 0 ? matchingIndex : 0;
    notifyListeners();
  }

  void _showNotification(DreameNotification notification) {
    final now = DateTime.now();
    final isDuplicate = notificationHistory.any(
      (item) =>
          item.entityId == notification.entityId &&
          item.category == notification.category &&
          item.title == notification.title &&
          item.body == notification.body &&
          now.difference(item.createdAt).abs() < const Duration(seconds: 5),
    );
    if (isDuplicate) return;
    notificationHistory.insert(
      0,
      VacuumNotificationRecord(
        category: notification.category,
        entityId: notification.entityId,
        title: notification.title,
        body: notification.body,
        createdAt: now,
      ),
    );
    if (notificationHistory.length > 30) notificationHistory.removeLast();
    unawaited(
      _secureStorage.write(
        key: _notificationHistoryKey,
        value: jsonEncode(
          notificationHistory.map((item) => item.toJson()).toList(),
        ),
      ),
    );
    final matches = vacuums.where(
      (vacuum) => vacuum.entityId == notification.entityId,
    );
    unawaited(
      _notificationPresenter.show(
        notification,
        vacuumName: matches.isEmpty ? null : matches.first.name,
      ),
    );
    notifyListeners();
  }

  void _restoreNotificationHistory(String? encoded) {
    if (encoded == null || encoded.isEmpty) return;
    try {
      final saved = jsonDecode(encoded) as List<dynamic>;
      notificationHistory
        ..clear()
        ..addAll(
          saved
              .whereType<Map<String, dynamic>>()
              .map(VacuumNotificationRecord.fromJson)
              .take(30),
        );
    } catch (_) {
      // A malformed local history must not block connection restoration.
    }
  }

  Future<void> _reloadNotificationHistory() async {
    _restoreNotificationHistory(
      await _secureStorage.read(key: _notificationHistoryKey),
    );
    notifyListeners();
  }

  void _updateConnectionStatus(HomeAssistantConnectionStatus status) {
    final wasDisconnected =
        connectionStatus != HomeAssistantConnectionStatus.connected;
    connectionStatus = status;
    notifyListeners();
    if (wasDisconnected &&
        status == HomeAssistantConnectionStatus.connected &&
        !isDemo) {
      unawaited(refreshSchedules());
    }
  }

  /// Move event delivery to the Android foreground-service isolate while the
  /// Flutter UI is suspended. The UI socket remains responsible for state
  /// updates whenever the app is visible.
  Future<void> enterBackground() async {
    if (isDemo || _client == null) return;
    await _notificationSubscription?.cancel();
    _notificationSubscription = null;
    await startBackgroundNotificationService();
  }

  Future<void> enterForeground() async {
    await stopBackgroundNotificationService();
    await _reloadNotificationHistory();
    if (_client != null && _notificationSubscription == null) {
      _notificationSubscription = _client!.notificationUpdates.listen(
        _showNotification,
      );
    }
  }

  void startDemo() {
    _vacuumSubscription?.cancel();
    _vacuumSubscription = null;
    _notificationSubscription?.cancel();
    _notificationSubscription = null;
    _connectionSubscription?.cancel();
    _connectionSubscription = null;
    _client?.close();
    _client = null;
    homeName = 'Kōwhai House';
    isDemo = true;
    connectionStatus = HomeAssistantConnectionStatus.connected;
    vacuums = [
      VacuumEntity(
        entityId: 'vacuum.orbit',
        name: 'Orbit',
        state: 'docked',
        battery: 86,
        fanSpeed: 'Balanced',
        fanSpeeds: ['Quiet', 'Balanced', 'Turbo'],
      ),
      VacuumEntity(
        entityId: 'vacuum.mini',
        name: 'Mini',
        state: 'cleaning',
        battery: 64,
        fanSpeed: 'Quiet',
        fanSpeeds: ['Quiet', 'Balanced', 'Turbo'],
      ),
    ];
    schedules.clear();
    scheduleError = null;
    _mapRoomLabels.clear();
    _vacuumSegments.clear();
    _vacuumSettings.clear();
    _segmentCleaningCapabilities.clear();
    _mapRoomLabels[vacuum.entityId] = [
      MapRoomLabel(id: 'demo-kitchen', name: 'Kitchen', segmentId: '1'),
      MapRoomLabel(id: 'demo-living-room', name: 'Living room', segmentId: '2'),
      MapRoomLabel(id: 'demo-bedroom', name: 'Bedroom', segmentId: '3'),
      MapRoomLabel(id: 'demo-hallway', name: 'Hallway', segmentId: '4'),
    ];
    _vacuumSegments[vacuum.entityId] = const [
      VacuumSegment(id: '1', name: 'Room 1'),
      VacuumSegment(id: '2', name: 'Room 2'),
      VacuumSegment(id: '3', name: 'Room 3'),
      VacuumSegment(id: '4', name: 'Room 4'),
    ];
    _segmentCleaningCapabilities[vacuum.entityId] =
        const SegmentCleaningCapability(
          domain: 'dreame_vacuum',
          service: 'vacuum_clean_segment',
          segmentField: 'segments',
          maximumRepeats: 3,
        );
    _vacuumSettings[vacuum.entityId] = [
      const VacuumSetting(
        entityId: 'select.orbit_cleangenius',
        name: 'CleanGenius',
        kind: VacuumSettingKind.select,
        value: 'Off',
        options: ['Off', 'Routine cleaning', 'Deep cleaning'],
      ),
      const VacuumSetting(
        entityId: 'select.orbit_cleaning_mode',
        name: 'Cleaning mode',
        kind: VacuumSettingKind.select,
        value: 'Vacuum and mop',
        options: ['Vacuum', 'Mop', 'Vacuum and mop', 'Mop after vacuum'],
      ),
      const VacuumSetting(
        entityId: 'select.orbit_carpet_cleaning_mode',
        name: 'Carpet cleaning mode',
        kind: VacuumSettingKind.select,
        value: 'Intensive',
        options: ['Avoid', 'Adaptation', 'Intensive'],
      ),
      const VacuumSetting(
        entityId: 'switch.orbit_clean_carpets_first',
        name: 'Clean carpets first',
        kind: VacuumSettingKind.toggle,
        value: 'on',
      ),
      const VacuumSetting(
        entityId: 'switch.orbit_carpet_boost',
        name: 'Carpet boost',
        kind: VacuumSettingKind.toggle,
        value: 'on',
      ),
      const VacuumSetting(
        entityId: 'select.orbit_cleaning_route',
        name: 'Cleaning route',
        kind: VacuumSettingKind.select,
        value: 'Standard',
        options: ['Quick', 'Standard', 'Deep'],
      ),
      const VacuumSetting(
        entityId: 'select.orbit_mop_wash_frequency',
        name: 'Mop wash frequency',
        kind: VacuumSettingKind.select,
        value: 'By area',
        options: ['By area', 'By room', 'By time'],
      ),
      const VacuumSetting(
        entityId: 'switch.orbit_auto_empty',
        name: 'Auto-empty after cleaning',
        kind: VacuumSettingKind.toggle,
        value: 'on',
      ),
      const VacuumSetting(
        entityId: 'number.orbit_drying_time',
        name: 'Mop drying time',
        kind: VacuumSettingKind.number,
        value: '3',
        minimum: 2,
        maximum: 4,
        step: 1,
        unit: 'h',
      ),
    ];
    notifyListeners();
  }

  void selectVacuum(int index) {
    selectedVacuum = index;
    notifyListeners();
    unawaited(refreshVacuumSettings());
  }

  Future<void> refreshVacuumSettings() async {
    if (vacuums.isEmpty) return;
    await refreshVacuumSettingsFor(vacuum.entityId);
  }

  Future<void> refreshVacuumSettingsFor(String entityId) async {
    if (isDemo || _client == null) return;
    settingsLoading = true;
    settingsError = null;
    notifyListeners();
    try {
      _vacuumSettings[entityId] = await _client!.fetchVacuumSettings(entityId);
    } catch (error) {
      settingsError = _message(error);
    } finally {
      settingsLoading = false;
      notifyListeners();
    }
  }

  Future<void> setVacuumSetting(VacuumSetting setting, Object? value) async {
    if (busySettingIds.contains(setting.entityId)) return;
    busySettingIds.add(setting.entityId);
    notifyListeners();
    try {
      if (!isDemo) await _client!.setVacuumSetting(setting, value);
      if (setting.kind != VacuumSettingKind.action) {
        final settings = _vacuumSettings[vacuum.entityId];
        final index =
            settings?.indexWhere((item) => item.entityId == setting.entityId) ??
            -1;
        if (settings != null && index >= 0) {
          settings[index] = setting.copyWithValue(
            setting.kind == VacuumSettingKind.toggle
                ? (value == true ? 'on' : 'off')
                : value.toString(),
          );
        }
      }
    } finally {
      busySettingIds.remove(setting.entityId);
      notifyListeners();
    }
  }

  Future<void> toggleCleaning() async {
    final current = vacuum;
    final service = current.isCleaning ? 'pause' : 'start';
    await _runService(service, current.isCleaning ? 'paused' : 'cleaning');
  }

  /// Ends the current task without sending the vacuum back to its dock.
  Future<void> stopCleaning() => _runService('stop', 'idle');

  Future<void> dock() => _runService('return_to_base', 'returning');
  Future<void> locate() => _runService('locate', vacuum.state);

  Future<void> setFanSpeed(String speed) async {
    if (isBusy || speed == vacuum.fanSpeed) return;
    isBusy = true;
    notifyListeners();
    try {
      if (!isDemo) {
        await _client?.callVacuumService(
          'set_fan_speed',
          vacuum.entityId,
          data: {'fan_speed': speed},
        );
      }
      vacuums[selectedVacuum] = vacuum.copyWith(fanSpeed: speed);
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  Future<void> addMapRoomLabel(String name, String segmentId) async {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) {
      throw const FormatException('A room name is required.');
    }
    final nearbyIndex = mapRoomLabels.indexWhere(
      (label) => label.segmentId == segmentId,
    );
    if (nearbyIndex >= 0) {
      mapRoomLabels[nearbyIndex] = mapRoomLabels[nearbyIndex].copyWith(
        name: normalizedName,
        segmentId: segmentId,
      );
    } else {
      mapRoomLabels.add(
        MapRoomLabel(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          name: normalizedName,
          segmentId: segmentId,
        ),
      );
    }
    await _persistRoomLabels();
    notifyListeners();
  }

  Future<void> renameMapRoomLabel(MapRoomLabel label, String name) async {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) {
      throw const FormatException('A room name is required.');
    }
    final index = mapRoomLabels.indexWhere((item) => item.id == label.id);
    if (index < 0) return;
    mapRoomLabels[index] = mapRoomLabels[index].copyWith(name: normalizedName);
    await _persistRoomLabels();
    notifyListeners();
  }

  Future<void> renameVacuum(String name) async {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) {
      throw const FormatException('A vacuum name is required.');
    }
    _vacuumNames[vacuum.entityId] = normalizedName;
    vacuums[selectedVacuum] = vacuum.copyWith(name: normalizedName);
    if (!isDemo) {
      await _secureStorage.write(
        key: _vacuumNamesKey,
        value: jsonEncode(_vacuumNames),
      );
    }
    notifyListeners();
  }

  VacuumEntity _withDisplayName(VacuumEntity item) {
    final name = _vacuumNames[item.entityId];
    return name == null ? item : item.copyWith(name: name);
  }

  void _restoreVacuumNames(String? encoded) {
    if (encoded == null || encoded.isEmpty) return;
    try {
      final stored = jsonDecode(encoded) as Map<String, dynamic>;
      _vacuumNames.addAll(
        stored.map((key, value) => MapEntry(key, value.toString())),
      );
    } on Object {
      // Ignore malformed local display names.
    }
  }

  Future<void> removeMapRoomLabel(MapRoomLabel label) async {
    mapRoomLabels.removeWhere((item) => item.id == label.id);
    await _persistRoomLabels();
    notifyListeners();
  }

  void _restoreRoomLabels(String? encoded) {
    if (encoded == null || encoded.isEmpty) return;
    try {
      final stored = jsonDecode(encoded) as Map<String, dynamic>;
      for (final entry in stored.entries) {
        final labels = entry.value as List<dynamic>;
        _mapRoomLabels[entry.key] = labels
            .whereType<Map<String, dynamic>>()
            .where((label) => label['segment_id'] != null)
            .map(MapRoomLabel.fromJson)
            .toList();
      }
    } on Object {
      // Ignore malformed data and allow the user to label the map again.
    }
  }

  Future<void> _persistRoomLabels() async {
    if (isDemo) return;
    final encoded = jsonEncode(
      _mapRoomLabels.map(
        (vacuumId, labels) => MapEntry(
          vacuumId,
          labels.map((label) => label.toJson()).toList(growable: false),
        ),
      ),
    );
    await _secureStorage.write(key: _roomLabelsKey, value: encoded);
  }

  Future<void> _loadVacuumSegments() async {
    roomCapabilityError = null;
    _vacuumSegments.clear();
    _segmentCleaningCapabilities.clear();
    final client = _client;
    if (client == null) return;
    SegmentCleaningCapability? capability;
    try {
      capability = await client.fetchSegmentCleaningCapability();
    } catch (error) {
      roomCapabilityError = _message(error);
    }
    for (final item in vacuums.where((item) => item.supportsAreaCleaning)) {
      try {
        _vacuumSegments[item.entityId] = await client.fetchVacuumSegments(
          item.entityId,
        );
        if (capability != null) {
          _segmentCleaningCapabilities[item.entityId] = capability;
        }
      } catch (error) {
        roomCapabilityError = _message(error);
      }
    }
  }

  Future<void> cleanRooms(List<String> segmentIds) async {
    if (isBusy) return;
    if (segmentIds.isEmpty) {
      throw const FormatException('Choose at least one cleanable room.');
    }
    isBusy = true;
    notifyListeners();
    try {
      if (!isDemo) {
        await _client!.cleanVacuumSegments(vacuum.entityId, segmentIds);
      }
      vacuums[selectedVacuum] = vacuum.copyWith(state: 'cleaning');
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  Future<void> _runService(String service, String newState) async {
    if (isBusy) return;
    isBusy = true;
    notifyListeners();
    try {
      if (!isDemo) await _client?.callVacuumService(service, vacuum.entityId);
      vacuums[selectedVacuum] = vacuum.copyWith(state: newState);
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  String vacuumName(String entityId) {
    final match = vacuums.where((vacuum) => vacuum.entityId == entityId);
    return match.isEmpty ? entityId : match.first.name;
  }

  Future<void> refreshSchedules() async {
    if (isDemo || _client == null) return;
    schedulesLoading = true;
    scheduleError = null;
    notifyListeners();
    try {
      final loaded = await _client!.fetchScrubbySchedules();
      final savedOrder = await _loadScheduleOrder();
      final loadedSchedules = loaded
          .map(CleaningSchedule.fromHomeAssistant)
          .toList(growable: false);
      schedules
        ..clear()
        ..addAll(_applyScheduleOrder(loadedSchedules, savedOrder));
      await _saveScheduleOrder();
    } catch (error) {
      scheduleError = _message(error);
    } finally {
      schedulesLoading = false;
      notifyListeners();
    }
  }

  Future<bool> addSchedule(CleaningSchedule schedule) async {
    if (isDemo) {
      schedules.add(schedule);
      notifyListeners();
      return true;
    }
    busyScheduleIds.add(schedule.id);
    scheduleError = null;
    notifyListeners();
    try {
      await _client!.createScrubbySchedule(
        id: schedule.id,
        title: schedule.title,
        time: schedule.time,
        weekdays: schedule.weekdays,
        vacuumEntityId: schedule.vacuumEntityId,
        fanSpeed: schedule.fanSpeed,
        settings: schedule.settings,
        segmentIds: schedule.segmentIds,
        cycles: schedule.cycles,
      );
      await refreshSchedules();
      return true;
    } catch (error) {
      scheduleError = _message(error);
      return false;
    } finally {
      busyScheduleIds.remove(schedule.id);
      notifyListeners();
    }
  }

  Future<bool> updateSchedule(CleaningSchedule schedule) async {
    final index = schedules.indexWhere((item) => item.id == schedule.id);
    if (index < 0) return false;
    if (isDemo) {
      schedules[index] = schedule;
      notifyListeners();
      return true;
    }
    busyScheduleIds.add(schedule.id);
    scheduleError = null;
    notifyListeners();
    try {
      await _client!.createScrubbySchedule(
        id: schedule.id,
        title: schedule.title,
        time: schedule.time,
        weekdays: schedule.weekdays,
        vacuumEntityId: schedule.vacuumEntityId,
        fanSpeed: schedule.fanSpeed,
        settings: schedule.settings,
        segmentIds: schedule.segmentIds,
        cycles: schedule.cycles,
      );
      await refreshSchedules();
      return true;
    } catch (error) {
      scheduleError = _message(error);
      return false;
    } finally {
      busyScheduleIds.remove(schedule.id);
      notifyListeners();
    }
  }

  Future<void> toggleSchedule(int index, bool value) async {
    final schedule = schedules[index];
    if (isDemo) {
      schedules[index] = schedule.copyWith(enabled: value);
      notifyListeners();
      return;
    }
    busyScheduleIds.add(schedule.id);
    scheduleError = null;
    schedules[index] = schedule.copyWith(enabled: value);
    notifyListeners();
    try {
      await _client!.setScrubbyScheduleEnabled(schedule.entityId, value);
    } catch (error) {
      schedules[index] = schedule;
      scheduleError = _message(error);
    } finally {
      busyScheduleIds.remove(schedule.id);
      notifyListeners();
    }
  }

  Future<void> deleteSchedule(int index) async {
    final schedule = schedules[index];
    busyScheduleIds.add(schedule.id);
    scheduleError = null;
    notifyListeners();
    try {
      if (!isDemo) await _client!.deleteScrubbySchedule(schedule.id);
      schedules.removeWhere((item) => item.id == schedule.id);
      await _saveScheduleOrder();
    } catch (error) {
      scheduleError = _message(error);
    } finally {
      busyScheduleIds.remove(schedule.id);
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await stopBackgroundNotificationService();
    await _secureStorage.delete(key: _urlKey);
    await _secureStorage.delete(key: _tokenKey);
    await _secureStorage.delete(key: _roomLabelsKey);
    await _secureStorage.delete(key: _scheduleOrderKey);
    await _vacuumSubscription?.cancel();
    _vacuumSubscription = null;
    await _notificationSubscription?.cancel();
    _notificationSubscription = null;
    await _connectionSubscription?.cancel();
    _connectionSubscription = null;
    await _client?.close();
    _client = null;
    vacuums = [];
    selectedVacuum = 0;
    _mapRoomLabels.clear();
    _vacuumSegments.clear();
    _vacuumSettings.clear();
    _segmentCleaningCapabilities.clear();
    schedules.clear();
    scheduleError = null;
    savedUrl = null;
    notifyListeners();
  }

  /// Moves a schedule in the displayed order and retains that preference
  /// between schedule refreshes.
  void reorderSchedules(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= schedules.length) return;
    if (newIndex < 0 || newIndex >= schedules.length || oldIndex == newIndex) {
      return;
    }
    final schedule = schedules.removeAt(oldIndex);
    schedules.insert(newIndex, schedule);
    unawaited(_saveScheduleOrder());
    notifyListeners();
  }

  Future<List<String>> _loadScheduleOrder() async {
    final value = await _secureStorage.read(key: _scheduleOrderKey);
    if (value == null) return const [];
    try {
      return (jsonDecode(value) as List<dynamic>).whereType<String>().toList(
        growable: false,
      );
    } catch (_) {
      return const [];
    }
  }

  List<CleaningSchedule> _applyScheduleOrder(
    List<CleaningSchedule> loaded,
    List<String> savedOrder,
  ) {
    if (savedOrder.isEmpty) return loaded;
    final positions = {
      for (var index = 0; index < savedOrder.length; index++)
        savedOrder[index]: index,
    };
    final originalPositions = {
      for (var index = 0; index < loaded.length; index++)
        loaded[index].id: index,
    };
    return [...loaded]..sort((a, b) {
      final aPosition =
          positions[a.id] ?? (savedOrder.length + originalPositions[a.id]!);
      final bPosition =
          positions[b.id] ?? (savedOrder.length + originalPositions[b.id]!);
      return aPosition.compareTo(bPosition);
    });
  }

  Future<void> _saveScheduleOrder() async {
    if (isDemo) return;
    try {
      await _secureStorage.write(
        key: _scheduleOrderKey,
        value: jsonEncode(schedules.map((schedule) => schedule.id).toList()),
      );
    } catch (_) {
      // Schedule ordering is a local preference, so a storage failure should
      // not make an otherwise successful schedule action appear to fail.
    }
  }

  String _message(Object error) {
    if (!isDemo &&
        connectionStatus != HomeAssistantConnectionStatus.connected) {
      return connectionStatus == HomeAssistantConnectionStatus.offline
          ? 'You’re offline. We’ll keep trying to reconnect.'
          : 'Connection error. Trying to reconnect.';
    }
    return error.toString().replaceFirst(
      RegExp(r'^(Exception|FormatException):\s*'),
      '',
    );
  }

  @override
  void dispose() {
    _vacuumSubscription?.cancel();
    _notificationSubscription?.cancel();
    _connectionSubscription?.cancel();
    _client?.close();
    super.dispose();
  }
}
