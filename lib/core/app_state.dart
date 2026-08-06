import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'home_assistant.dart';

class CleaningSchedule {
  const CleaningSchedule({
    required this.title,
    required this.days,
    required this.time,
    required this.rooms,
    this.enabled = true,
  });

  final String title;
  final String days;
  final String time;
  final String rooms;
  final bool enabled;

  CleaningSchedule copyWith({bool? enabled}) => CleaningSchedule(
    title: title,
    days: days,
    time: time,
    rooms: rooms,
    enabled: enabled ?? this.enabled,
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
  List<VacuumEntity> vacuums = [];
  int selectedVacuum = 0;
  String homeName = 'Home';
  bool isDemo = false;
  bool isBusy = false;
  bool isInitialized = false;
  String? savedUrl;
  String? restoreError;
  final Map<String, List<MapRoomLabel>> _mapRoomLabels = {};

  final List<CleaningSchedule> schedules = [
    const CleaningSchedule(
      title: 'Weekday refresh',
      days: 'MON · WED · FRI',
      time: '09:30',
      rooms: 'Kitchen + Living room',
    ),
    const CleaningSchedule(
      title: 'Sunday reset',
      days: 'SUN',
      time: '11:00',
      rooms: 'Whole home',
      enabled: false,
    ),
  ];

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
    final location = await client.connect();
    final entities = await client.fetchVacuums();
    if (entities.isEmpty) {
      throw Exception('Connected, but no vacuum entities were found.');
    }
    _client = client;
    homeName = location;
    vacuums = entities;
    isDemo = false;
    savedUrl = client.baseUrl;
    restoreError = null;
    if (persist) {
      await _secureStorage.write(key: _urlKey, value: client.baseUrl);
      await _secureStorage.write(key: _tokenKey, value: token.trim());
    }
    notifyListeners();
  }

  void startDemo() {
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

  void toggleSchedule(int index, bool value) {
    schedules[index] = schedules[index].copyWith(enabled: value);
    notifyListeners();
  }

  void addSchedule(CleaningSchedule schedule) {
    schedules.add(schedule);
    notifyListeners();
  }

  Future<void> logout() async {
    await _secureStorage.delete(key: _urlKey);
    await _secureStorage.delete(key: _tokenKey);
    _client = null;
    vacuums = [];
    selectedVacuum = 0;
    _mapRoomLabels.clear();
    savedUrl = null;
    notifyListeners();
  }
}
