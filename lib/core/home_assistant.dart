import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

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
      name: attributes['friendly_name'] as String? ?? 'Robot vacuum',
      state: json['state'] as String? ?? 'unknown',
      battery: _readBattery(attributes),
      fanSpeed: attributes['fan_speed']?.toString(),
      fanSpeeds: (attributes['fan_speed_list'] as List<dynamic>? ?? const [])
          .map((value) => value.toString())
          .toList(growable: false),
    );
  }
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
  HomeAssistantClient(String url, this.token)
    : baseUrl = url.trim().replaceFirst(RegExp(r'/$'), '');

  final String baseUrl;
  final String token;

  Map<String, String> get _headers => {
    'Authorization': 'Bearer $token',
    'Content-Type': 'application/json',
  };

  Future<String> connect() async {
    final response = await http
        .get(Uri.parse('$baseUrl/api/config'), headers: _headers)
        .timeout(const Duration(seconds: 12));
    if (response.statusCode == 401) {
      throw Exception('That access token was not accepted.');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Home Assistant responded with ${response.statusCode}.');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data['location_name'] as String? ?? 'Home';
  }

  Future<List<VacuumEntity>> fetchVacuums() async {
    final response = await http
        .get(Uri.parse('$baseUrl/api/states'), headers: _headers)
        .timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) {
      throw Exception('Could not load Home Assistant entities.');
    }
    final states = (jsonDecode(response.body) as List<dynamic>)
        .cast<Map<String, dynamic>>();
    final vacuumStates = states.where(
      (item) => (item['entity_id'] as String).startsWith('vacuum.'),
    );
    final vacuums = <VacuumEntity>[];
    for (final state in vacuumStates) {
      var vacuum = VacuumEntity.fromJson(state);
      final battery = vacuum.battery ?? _findBattery(state, states);
      final mapEntity = _findMapEntity(state, states);
      final mapImage = mapEntity == null ? null : await _fetchMap(mapEntity);
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

  Future<Uint8List?> _fetchMap(Map<String, dynamic> entity) async {
    final entityId = entity['entity_id'] as String;
    final domain = entityId.split('.').first;
    final endpoint = domain == 'camera' ? 'camera_proxy' : 'image_proxy';
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/api/$endpoint/$entityId'), headers: _headers)
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
    final response = await http
        .post(
          Uri.parse('$baseUrl/api/services/vacuum/$service'),
          headers: _headers,
          body: jsonEncode({'entity_id': entityId, ...data}),
        )
        .timeout(const Duration(seconds: 12));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Home Assistant could not run “$service”.');
    }
  }
}
