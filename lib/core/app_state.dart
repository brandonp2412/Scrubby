import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'home_assistant.dart';

class CleaningSchedule {
  const CleaningSchedule({
    required this.id,
    required this.entityId,
    required this.title,
    required this.weekdays,
    required this.time,
    required this.vacuumEntityId,
    this.enabled = true,
  });

  final String id;
  final String entityId;
  final String title;
  final List<int> weekdays;
  final String time;
  final String vacuumEntityId;
  final bool enabled;

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
      );
}

class MapRoomLabel {
  const MapRoomLabel({required this.name, required this.x, required this.y});

  final String name;
  final double x;
  final double y;
}

class AppState extends ChangeNotifier {
  AppState({FlutterSecureStorage? secureStorage})
    : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  static const _urlKey = 'home_assistant_url';
  static const _tokenKey = 'home_assistant_token';
  final FlutterSecureStorage _secureStorage;
  HomeAssistantClient? _client;
  StreamSubscription<List<VacuumEntity>>? _vacuumSubscription;
  List<VacuumEntity> vacuums = [];
  int selectedVacuum = 0;
  String homeName = 'Home';
  bool isDemo = false;
  bool isBusy = false;
  bool isInitialized = false;
  String? savedUrl;
  String? restoreError;
  final Map<String, List<MapRoomLabel>> _mapRoomLabels = {};

  final List<CleaningSchedule> schedules = [];
  bool schedulesLoading = false;
  String? scheduleError;
  final Set<String> busyScheduleIds = {};

  VacuumEntity get vacuum => vacuums[selectedVacuum];
  List<MapRoomLabel> get mapRoomLabels =>
      _mapRoomLabels.putIfAbsent(vacuum.entityId, () => []);

  Future<void> initialize() async {
    try {
      final credentials = await _secureStorage.readAll();
      savedUrl = credentials[_urlKey];
      final token = credentials[_tokenKey];
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
      await _client?.close();
      _client = client;
      _vacuumSubscription = client.vacuumUpdates.listen(_applyVacuumUpdate);
      homeName = location;
      vacuums = entities;
      selectedVacuum = 0;
      isDemo = false;
      savedUrl = client.baseUrl;
      restoreError = null;
      notifyListeners();
      await refreshSchedules();
    } catch (_) {
      await client.close();
      rethrow;
    }
  }

  void _applyVacuumUpdate(List<VacuumEntity> updated) {
    if (updated.isEmpty) return;
    final selectedId = vacuums.isEmpty ? null : vacuum.entityId;
    vacuums = updated;
    final matchingIndex = selectedId == null
        ? -1
        : vacuums.indexWhere((item) => item.entityId == selectedId);
    selectedVacuum = matchingIndex >= 0 ? matchingIndex : 0;
    notifyListeners();
  }

  void startDemo() {
    _vacuumSubscription?.cancel();
    _vacuumSubscription = null;
    _client?.close();
    _client = null;
    homeName = 'Kōwhai House';
    isDemo = true;
    vacuums = const [
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
    notifyListeners();
  }

  void selectVacuum(int index) {
    selectedVacuum = index;
    notifyListeners();
  }

  Future<void> toggleCleaning() async {
    final current = vacuum;
    final service = current.isCleaning ? 'pause' : 'start';
    await _runService(service, current.isCleaning ? 'paused' : 'cleaning');
  }

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

  void addMapRoomLabel(String name, double x, double y) {
    mapRoomLabels.add(MapRoomLabel(name: name, x: x, y: y));
    notifyListeners();
  }

  void removeMapRoomLabel(MapRoomLabel label) {
    mapRoomLabels.remove(label);
    notifyListeners();
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
      schedules
        ..clear()
        ..addAll(loaded.map(CleaningSchedule.fromHomeAssistant));
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
    } catch (error) {
      scheduleError = _message(error);
    } finally {
      busyScheduleIds.remove(schedule.id);
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await _secureStorage.delete(key: _urlKey);
    await _secureStorage.delete(key: _tokenKey);
    await _vacuumSubscription?.cancel();
    _vacuumSubscription = null;
    await _client?.close();
    _client = null;
    vacuums = [];
    selectedVacuum = 0;
    _mapRoomLabels.clear();
    schedules.clear();
    scheduleError = null;
    savedUrl = null;
    notifyListeners();
  }

  String _message(Object error) => error.toString().replaceFirst(
    RegExp(r'^(Exception|FormatException):\s*'),
    '',
  );

  @override
  void dispose() {
    _vacuumSubscription?.cancel();
    _client?.close();
    super.dispose();
  }
}
