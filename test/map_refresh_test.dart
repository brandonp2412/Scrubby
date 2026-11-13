import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:scrubby/core/home_assistant.dart';

void main() {
  test(
    'rapid camera events cannot defer the first map or overlap downloads',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      late WebSocket socket;
      var fetches = 0;
      var inFlight = 0;
      var maxInFlight = 0;
      final mapClient = MockClient((request) async {
        expect(request.url.path, '/api/camera_proxy/camera.test_map');
        fetches++;
        final frame = fetches;
        inFlight++;
        if (inFlight > maxInFlight) maxInFlight = inFlight;
        try {
          await Future<void>.delayed(const Duration(milliseconds: 550));
          return http.Response.bytes([frame], HttpStatus.ok);
        } finally {
          inFlight--;
        }
      });

      server.listen((request) async {
        socket = await WebSocketTransformer.upgrade(request);
        socket.add(jsonEncode({'type': 'auth_required'}));
        socket.listen((rawMessage) {
          final command =
              jsonDecode(rawMessage as String) as Map<String, dynamic>;
          final type = command['type'];
          if (type == 'auth') {
            socket.add(jsonEncode({'type': 'auth_ok'}));
          } else if (type == 'get_config') {
            socket.add(
              jsonEncode({
                'id': command['id'],
                'type': 'result',
                'success': true,
                'result': {'location_name': 'Test'},
              }),
            );
          } else if (type == 'get_states') {
            socket.add(
              jsonEncode({
                'id': command['id'],
                'type': 'result',
                'success': true,
                'result': [
                  {
                    'entity_id': 'vacuum.test',
                    'state': 'cleaning',
                    'attributes': {'friendly_name': 'Test Vacuum'},
                  },
                  {
                    'entity_id': 'camera.test_map',
                    'state': 'streaming',
                    'attributes': {'friendly_name': 'Test Vacuum Map'},
                  },
                ],
              }),
            );
          } else if (type == 'subscribe_events') {
            socket.add(
              jsonEncode({
                'id': command['id'],
                'type': 'result',
                'success': true,
                'result': null,
              }),
            );
          }
        });
      });

      final client = HomeAssistantClient(
        'http://${server.address.address}:${server.port}',
        'test-token',
        httpClient: mapClient,
        mapCatchupAttempts: 0,
      );
      addTearDown(client.close);
      await client.connect();
      expect((await client.fetchVacuums()).single.mapImage, isNull);
      client.refreshMaps();

      // Faster than the old 350ms debounce: this previously starved the map.
      for (var i = 0; i < 10; i++) {
        socket.add(
          jsonEncode({
            'type': 'event',
            'event': {
              'event_type': 'state_changed',
              'data': {
                'entity_id': 'camera.test_map',
                'new_state': {
                  'entity_id': 'camera.test_map',
                  'state': 'streaming',
                  'attributes': {'friendly_name': 'Test Vacuum Map'},
                },
              },
            },
          }),
        );
        await Future<void>.delayed(const Duration(milliseconds: 80));
        if (i == 5) {
          expect(
            fetches,
            1,
            reason: 'camera events must not postpone first frame',
          );
        }
      }
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      expect(fetches, greaterThanOrEqualTo(2));
      expect(maxInFlight, 1, reason: 'map HTTP requests must not pile up');
    },
  );
}
