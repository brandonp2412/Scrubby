import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:scrubby/main.dart';
import 'package:scrubby/core/app_state.dart';
import 'package:scrubby/core/home_assistant.dart';
import 'package:scrubby/screens/dashboard_shell.dart';
import 'package:scrubby/screens/home_page.dart';
import 'package:scrubby/screens/rooms_page.dart';
import 'package:scrubby/screens/schedules_page.dart';
import 'package:scrubby/screens/settings_page.dart';

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  testWidgets('shows Home Assistant connection screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ScrubbyApp());
    await tester.pumpAndSettle();
    expect(find.text('Connect your home'), findsOneWidget);
    expect(find.text('Explore with demo home'), findsOneWidget);
  });

  testWidgets('demo home opens the vacuum dashboard', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const ScrubbyApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Explore with demo home'));
    await tester.pumpAndSettle();

    expect(find.text('Orbit'), findsWidgets);
    expect(find.text('START'), findsOneWidget);
    expect(find.text('Today at a glance'), findsOneWidget);
  });

  testWidgets('tapping a schedule opens it for editing', (
    WidgetTester tester,
  ) async {
    final state = AppState()..startDemo();
    await state.addSchedule(
      const CleaningSchedule(
        id: 'scrubby_morning',
        entityId: '',
        title: 'Morning clean',
        weekdays: [DateTime.monday, DateTime.wednesday],
        time: '09:30',
        vacuumEntityId: 'vacuum.orbit',
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SchedulesPage(state: state)),
      ),
    );

    await tester.tap(find.text('Morning clean'));
    await tester.pumpAndSettle();

    expect(find.text('Edit schedule'), findsOneWidget);
    expect(find.text('Save changes'), findsOneWidget);
    final nameField = find.bySemanticsLabel('Name');
    expect(nameField, findsOneWidget);
    await tester.enterText(nameField, 'Evening clean');
    final saveButton = find.text('Save changes');
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(state.schedules, hasLength(1));
    expect(state.schedules.single.id, 'scrubby_morning');
    expect(state.schedules.single.title, 'Evening clean');
    expect(state.schedules.single.time, '09:30');
  });

  test('reorders schedules in their displayed order', () {
    final state = AppState()..startDemo();
    state.schedules.addAll([
      const CleaningSchedule(
        id: 'scrubby_first',
        entityId: '',
        title: 'First',
        weekdays: [DateTime.monday],
        time: '09:00',
        vacuumEntityId: 'vacuum.orbit',
      ),
      const CleaningSchedule(
        id: 'scrubby_second',
        entityId: '',
        title: 'Second',
        weekdays: [DateTime.tuesday],
        time: '10:00',
        vacuumEntityId: 'vacuum.orbit',
      ),
      const CleaningSchedule(
        id: 'scrubby_third',
        entityId: '',
        title: 'Third',
        weekdays: [DateTime.wednesday],
        time: '11:00',
        vacuumEntityId: 'vacuum.orbit',
      ),
    ]);

    state.reorderSchedules(0, 2);

    expect(state.schedules.map((schedule) => schedule.id), [
      'scrubby_second',
      'scrubby_third',
      'scrubby_first',
    ]);
  });

  test('reads battery values without inventing zero for missing data', () {
    VacuumEntity entityWith(Map<String, Object?> attributes) =>
        VacuumEntity.fromJson({
          'entity_id': 'vacuum.test',
          'state': 'docked',
          'attributes': attributes,
        });

    expect(entityWith({'battery_percentage': '72%'}).battery, 72);
    expect(entityWith({'battery': 54.6}).battery, 55);
    expect(entityWith({}).battery, isNull);
  });

  test(
    'does not match unrelated battery or map entities through missing names',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      var mapFetches = 0;
      final mapClient = MockClient((request) async {
        mapFetches++;
        return http.Response.bytes([1], HttpStatus.ok);
      });
      server.listen((request) async {
        final socket = await WebSocketTransformer.upgrade(request);
        socket.add(jsonEncode({'type': 'auth_required'}));
        socket.listen((rawMessage) {
          final message =
              jsonDecode(rawMessage as String) as Map<String, dynamic>;
          switch (message['type']) {
            case 'auth':
              socket.add(jsonEncode({'type': 'auth_ok'}));
            case 'get_config':
              socket.add(
                jsonEncode({
                  'id': message['id'],
                  'type': 'result',
                  'success': true,
                  'result': {'location_name': 'Test Home'},
                }),
              );
            case 'get_states':
              socket.add(
                jsonEncode({
                  'id': message['id'],
                  'type': 'result',
                  'success': true,
                  'result': [
                    {
                      'entity_id': 'vacuum.unnamed',
                      'state': 'docked',
                      'attributes': <String, Object?>{},
                    },
                    {
                      'entity_id': 'sensor.kitchen_battery',
                      'state': '81',
                      'attributes': {'device_class': 'battery'},
                    },
                    {
                      'entity_id': 'sensor.hall_battery',
                      'state': '42',
                      'attributes': {'device_class': 'battery'},
                    },
                    {
                      'entity_id': 'camera.kitchen_map',
                      'state': 'streaming',
                      'attributes': <String, Object?>{},
                    },
                    {
                      'entity_id': 'camera.hall_map',
                      'state': 'streaming',
                      'attributes': <String, Object?>{},
                    },
                  ],
                }),
              );
            case 'subscribe_events':
              socket.add(
                jsonEncode({
                  'id': message['id'],
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
      );
      addTearDown(client.close);
      await client.connect();

      final vacuum = (await client.fetchVacuums()).single;

      expect(vacuum.battery, isNull);
      expect(vacuum.mapImage, isNull);
      expect(mapFetches, 0);
    },
  );

  test(
    'finishing a fan-speed command updates the vacuum it started on',
    () async {
      final client = _DelayedVacuumClient();
      addTearDown(client.close);
      final state = AppState()
        ..setClientForTesting(client)
        ..vacuums = [
          const VacuumEntity(
            entityId: 'vacuum.first',
            name: 'First',
            state: 'docked',
            battery: 80,
            fanSpeed: 'Balanced',
          ),
          VacuumEntity(
            entityId: 'vacuum.second',
            name: 'Second',
            state: 'docked',
            battery: 70,
            fanSpeed: 'Quiet',
          ),
        ];

      final command = state.setFanSpeed('Turbo');
      await client.serviceStarted.future;
      state.selectedVacuum = 1;
      client.releaseService.complete();
      await command;

      expect(client.serviceEntityId, 'vacuum.first');
      expect(state.vacuums[0].fanSpeed, 'Turbo');
      expect(state.vacuums[1].fanSpeed, 'Quiet');
    },
  );

  test('finishing a room clean updates the vacuum it started on', () async {
    final client = _DelayedVacuumClient();
    addTearDown(client.close);
    final state = AppState()
      ..setClientForTesting(client)
      ..vacuums = [
        const VacuumEntity(
          entityId: 'vacuum.first',
          name: 'First',
          state: 'docked',
          battery: 80,
        ),
        const VacuumEntity(
          entityId: 'vacuum.second',
          name: 'Second',
          state: 'docked',
          battery: 70,
        ),
      ];

    final command = state.cleanRooms(const ['1']);
    await client.roomsStarted.future;
    state.selectedVacuum = 1;
    client.releaseRooms.complete();
    await command;

    expect(client.roomsEntityId, 'vacuum.first');
    expect(state.vacuums[0].state, 'cleaning');
    expect(state.vacuums[1].state, 'docked');
  });

  test(
    'an older settings refresh cannot clear a newer loading state',
    () async {
      final client = _DelayedVacuumClient();
      addTearDown(client.close);
      final state = AppState()
        ..setClientForTesting(client)
        ..vacuums = [
          const VacuumEntity(
            entityId: 'vacuum.first',
            name: 'First',
            state: 'docked',
            battery: 80,
          ),
          const VacuumEntity(
            entityId: 'vacuum.second',
            name: 'Second',
            state: 'docked',
            battery: 70,
          ),
        ];

      final first = state.refreshVacuumSettingsFor('vacuum.first');
      final second = state.refreshVacuumSettingsFor('vacuum.second');
      client.settingFetches['vacuum.first']!.completeError(Exception('stale'));
      await first;

      expect(state.settingsLoading, isTrue);
      expect(state.settingsError, isNull);

      client.settingFetches['vacuum.second']!.complete(const []);
      await second;

      expect(state.settingsLoading, isFalse);
      expect(state.settingsError, isNull);
    },
  );

  test('finishing a setting write updates the vacuum it started on', () async {
    const setting = VacuumSetting(
      entityId: 'select.first_cleaning_route',
      name: 'Cleaning route',
      kind: VacuumSettingKind.select,
      value: 'Standard',
      options: ['Standard', 'Deep'],
    );
    final client = _DelayedVacuumClient();
    addTearDown(client.close);
    final state = AppState()
      ..setClientForTesting(client)
      ..vacuums = [
        const VacuumEntity(
          entityId: 'vacuum.first',
          name: 'First',
          state: 'docked',
          battery: 80,
        ),
        const VacuumEntity(
          entityId: 'vacuum.second',
          name: 'Second',
          state: 'docked',
          battery: 70,
        ),
      ];

    final load = state.refreshVacuumSettingsFor('vacuum.first');
    client.settingFetches['vacuum.first']!.complete([setting]);
    await load;

    final write = state.setVacuumSetting(setting, 'Deep');
    await client.settingWriteStarted.future;
    state.selectedVacuum = 1;
    client.releaseSettingWrite.complete();
    await write;
    state.selectedVacuum = 0;

    expect(state.vacuumSettings.single.value, 'Deep');
  });

  test(
    'a failed schedule toggle reverts the schedule that was toggled',
    () async {
      final client = _DelayedVacuumClient();
      addTearDown(client.close);
      final state = AppState()..setClientForTesting(client);
      state.schedules.addAll(const [
        CleaningSchedule(
          id: 'scrubby_first',
          entityId: 'automation.scrubby_first',
          title: 'First',
          weekdays: [DateTime.monday],
          time: '09:00',
          vacuumEntityId: 'vacuum.first',
        ),
        CleaningSchedule(
          id: 'scrubby_second',
          entityId: 'automation.scrubby_second',
          title: 'Second',
          weekdays: [DateTime.tuesday],
          time: '10:00',
          vacuumEntityId: 'vacuum.first',
        ),
      ]);

      final toggle = state.toggleSchedule(0, false);
      await client.scheduleToggleStarted.future;
      final moved = state.schedules.removeAt(0);
      state.schedules.add(moved);
      client.releaseScheduleToggle.complete();
      await toggle;

      expect(state.schedules.map((schedule) => schedule.id), [
        'scrubby_second',
        'scrubby_first',
      ]);
      expect(state.schedules.last.enabled, isTrue);
    },
  );

  test('can end a paused cleaning run', () async {
    final state = AppState()..startDemo();

    await state.toggleCleaning();
    expect(state.vacuum.state, 'cleaning');
    await state.toggleCleaning();
    expect(state.vacuum.state, 'paused');

    await state.stopCleaning();
    expect(state.vacuum.state, 'idle');
  });

  test('shows only the device portion of a repeated friendly name', () {
    VacuumEntity entityWith(String friendlyName) => VacuumEntity.fromJson({
      'entity_id': 'vacuum.test',
      'state': 'docked',
      'attributes': {'friendly_name': friendlyName},
    });

    expect(entityWith('FloorSlut FloorSlut').name, 'FloorSlut');
    expect(
      entityWith('Living Room Vacuum Living Room Vacuum').name,
      'Living Room Vacuum',
    );
    expect(entityWith('Living Room Vacuum').name, 'Living Room Vacuum');
  });

  test('parses every Dreame Home Assistant notification event family', () {
    DreameNotification parse(String type, Map<String, Object?> data) =>
        DreameNotification.fromHomeAssistantEvent({
          'event_type': 'dreame_vacuum_$type',
          'data': {'entity_id': 'vacuum.dreame', ...data},
        })!;

    expect(
      parse('task_status', {
        'completed': true,
        'cleaned_area': 42,
        'cleaning_time': 55,
      }).category,
      DreameNotificationCategory.cleanup,
    );
    expect(
      parse('consumable', {'consumable': 'main_brush'}).body,
      contains('main brush'),
    );
    expect(
      parse('information', {'information': 'dust_collection'}).category,
      DreameNotificationCategory.information,
    );
    expect(
      parse('warning', {'warning': 'Clean water tank', 'code': 12}).code,
      12,
    );
    expect(
      parse('error', {'error': 'Wheel blocked', 'code': 3}).category,
      DreameNotificationCategory.error,
    );
  });

  test('loads only Scrubby-owned Home Assistant schedules', () async {
    final client = HomeAssistantClient(
      'http://homeassistant.local:8123',
      'test-token',
      httpClient: MockClient((request) async {
        expect(
          request.headers[HttpHeaders.authorizationHeader],
          'Bearer test-token',
        );
        if (request.url.path == '/api/states') {
          return http.Response(
            jsonEncode([
              {
                'entity_id': 'automation.scrubby_morning_clean',
                'state': 'on',
                'attributes': {
                  'id': 'scrubby_123',
                  'friendly_name': 'Morning clean',
                },
              },
              {
                'entity_id': 'automation.unrelated',
                'state': 'on',
                'attributes': {
                  'id': 'ordinary_automation',
                  'friendly_name': 'Unrelated',
                },
              },
            ]),
            HttpStatus.ok,
          );
        }
        expect(request.url.path, '/api/config/automation/config/scrubby_123');
        return http.Response(
          jsonEncode({
            'alias': 'Morning clean',
            'trigger': [
              {'platform': 'time', 'at': '09:30:00'},
            ],
            'condition': [
              {
                'condition': 'time',
                'weekday': ['mon', 'wed', 'fri'],
              },
            ],
            'action': [
              {
                'alias': 'Set suction power',
                'service': 'vacuum.set_fan_speed',
                'target': {'entity_id': 'vacuum.test'},
                'data': {'fan_speed': 'Turbo'},
              },
              {
                'alias': 'Set Cleaning route',
                'service': 'select.select_option',
                'target': {'entity_id': 'select.test_cleaning_route'},
                'data': {'option': 'Deep'},
              },
              {
                'service': 'vacuum.start',
                'target': {'entity_id': 'vacuum.test'},
              },
            ],
          }),
          HttpStatus.ok,
        );
      }),
    );
    addTearDown(client.close);

    final schedules = await client.fetchScrubbySchedules();

    expect(schedules, hasLength(1));
    expect(schedules.single.id, 'scrubby_123');
    expect(schedules.single.entityId, 'automation.scrubby_morning_clean');
    expect(schedules.single.title, 'Morning clean');
    expect(schedules.single.time, '09:30');
    expect(schedules.single.weekdays, [1, 3, 5]);
    expect(schedules.single.vacuumEntityId, 'vacuum.test');
    expect(schedules.single.enabled, isTrue);
    expect(schedules.single.fanSpeed, 'Turbo');
    expect(schedules.single.settings.single.name, 'Cleaning route');
    expect(schedules.single.settings.single.value, 'Deep');
  });

  test('creates a Home Assistant automation and reloads automations', () async {
    var reloaded = false;
    final client = HomeAssistantClient(
      'http://homeassistant.local:8123',
      'test-token',
      httpClient: MockClient((request) async {
        if (request.url.path == '/api/config/automation/config/scrubby_456') {
          expect(request.method, 'POST');
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['alias'], 'After lunch');
          expect(body['trigger'], [
            {'platform': 'time', 'at': '13:15:00'},
          ]);
          expect(body['condition'], [
            {
              'condition': 'time',
              'weekday': ['tue', 'thu'],
            },
          ]);
          expect(body['action'], [
            {
              'service': 'vacuum.start',
              'target': {'entity_id': 'vacuum.downstairs'},
            },
          ]);
          return http.Response('{"result":"ok"}', HttpStatus.ok);
        }
        expect(request.url.path, '/api/services/automation/reload');
        expect(request.method, 'POST');
        reloaded = true;
        return http.Response('[]', HttpStatus.ok);
      }),
    );
    addTearDown(client.close);

    await client.createScrubbySchedule(
      id: 'scrubby_456',
      title: 'After lunch',
      time: '13:15',
      weekdays: [DateTime.tuesday, DateTime.thursday],
      vacuumEntityId: 'vacuum.downstairs',
    );

    expect(reloaded, isTrue);
  });

  test('schedules selected Dreame rooms with supported cycles', () async {
    late List<dynamic> actions;
    final client = HomeAssistantClient(
      'http://homeassistant.local:8123',
      'test-token',
      httpClient: MockClient((request) async {
        if (request.method == 'GET' && request.url.path == '/api/services') {
          return http.Response(
            jsonEncode([
              {
                'domain': 'dreame_vacuum',
                'services': {
                  'vacuum_clean_segment': {
                    'fields': {
                      'segments': {},
                      'repeats': {
                        'selector': {
                          'number': {'min': 1, 'max': 3},
                        },
                      },
                    },
                  },
                },
              },
            ]),
            HttpStatus.ok,
          );
        }
        if (request.url.path == '/api/config/automation/config/scrubby_rooms') {
          actions =
              (jsonDecode(request.body) as Map<String, dynamic>)['action']
                  as List<dynamic>;
          return http.Response('{"result":"ok"}', HttpStatus.ok);
        }
        expect(request.url.path, '/api/services/automation/reload');
        return http.Response('[]', HttpStatus.ok);
      }),
    );
    addTearDown(client.close);

    await client.createScrubbySchedule(
      id: 'scrubby_rooms',
      title: 'Kitchen and hall',
      time: '11:00',
      weekdays: [DateTime.monday],
      vacuumEntityId: 'vacuum.dreame',
      segmentIds: const ['2', '4'],
      cycles: 2,
      fanSpeed: 'Turbo',
      settings: const [
        VacuumSetting(
          entityId: 'select.dreame_cleangenius',
          name: 'CleanGenius',
          kind: VacuumSettingKind.select,
          value: 'Off',
        ),
      ],
    );

    expect(actions.map((action) => action['service']), [
      'select.select_option',
      'vacuum.set_fan_speed',
      'dreame_vacuum.vacuum_clean_segment',
    ]);
    expect(actions.last['data'], {
      'segments': [2, 4],
      'repeats': 2,
    });
  });

  test('adds selected cleaning preferences before a scheduled clean', () async {
    late List<dynamic> actions;
    final client = HomeAssistantClient(
      'http://homeassistant.local:8123',
      'test-token',
      httpClient: MockClient((request) async {
        if (request.url.path == '/api/config/automation/config/scrubby_modes') {
          actions =
              (jsonDecode(request.body) as Map<String, dynamic>)['action']
                  as List<dynamic>;
          return http.Response('{"result":"ok"}', HttpStatus.ok);
        }
        return http.Response('[]', HttpStatus.ok);
      }),
    );
    addTearDown(client.close);

    await client.createScrubbySchedule(
      id: 'scrubby_modes',
      title: 'Deep clean',
      time: '10:00',
      weekdays: [DateTime.saturday],
      vacuumEntityId: 'vacuum.dreame',
      fanSpeed: 'Turbo',
      settings: const [
        VacuumSetting(
          entityId: 'select.dreame_cleaning_mode',
          name: 'Cleaning mode',
          kind: VacuumSettingKind.select,
          value: 'Sweeping and mopping',
        ),
        VacuumSetting(
          entityId: 'select.dreame_cleaning_route',
          name: 'Cleaning route',
          kind: VacuumSettingKind.select,
          value: 'Deep',
        ),
      ],
    );

    expect(actions.map((action) => action['service']), [
      'vacuum.set_fan_speed',
      'select.select_option',
      'select.select_option',
      'vacuum.start',
    ]);
    expect(actions[0]['data'], {'fan_speed': 'Turbo'});
    expect(actions[1]['data'], {'option': 'Sweeping and mopping'});
    expect(actions[2]['data'], {'option': 'Deep'});
  });

  test(
    'uses native Home Assistant services for discovered robot settings',
    () async {
      final calls = <Map<String, dynamic>>[];
      final client = HomeAssistantClient(
        'http://homeassistant.local:8123',
        'test-token',
        httpClient: MockClient((request) async {
          calls.add({
            'path': request.url.path,
            'body': jsonDecode(request.body),
          });
          return http.Response('[]', HttpStatus.ok);
        }),
      );
      addTearDown(client.close);

      await client.setVacuumSetting(
        const VacuumSetting(
          entityId: 'switch.dreame_clean_carpets_first',
          name: 'Clean carpets first',
          kind: VacuumSettingKind.toggle,
          value: 'off',
        ),
        true,
      );
      await client.setVacuumSetting(
        const VacuumSetting(
          entityId: 'select.dreame_carpet_cleaning_mode',
          name: 'Carpet cleaning mode',
          kind: VacuumSettingKind.select,
          value: 'Avoid',
        ),
        'Intensive',
      );

      expect(calls, [
        {
          'path': '/api/services/switch/turn_on',
          'body': {'entity_id': 'switch.dreame_clean_carpets_first'},
        },
        {
          'path': '/api/services/select/select_option',
          'body': {
            'entity_id': 'select.dreame_carpet_cleaning_mode',
            'option': 'Intensive',
          },
        },
      ]);
    },
  );

  test(
    'discovers HA vacuum segments and runs the Dreame room service',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      Map<String, dynamic>? servicePayload;
      final apiClient = MockClient((request) async {
        if (request.method == 'GET' && request.url.path == '/api/services') {
          return http.Response(
            jsonEncode([
              {
                'domain': 'dreame_vacuum',
                'services': {
                  'vacuum_clean_segment': {
                    'fields': {'segments': {}},
                  },
                },
              },
            ]),
            HttpStatus.ok,
          );
        }
        expect(
          request.url.path,
          '/api/services/dreame_vacuum/vacuum_clean_segment',
        );
        servicePayload = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response('[]', HttpStatus.ok);
      });
      server.listen((request) async {
        final socket = await WebSocketTransformer.upgrade(request);
        socket.add(jsonEncode({'type': 'auth_required'}));
        socket.listen((rawMessage) {
          final message =
              jsonDecode(rawMessage as String) as Map<String, dynamic>;
          switch (message['type']) {
            case 'auth':
              socket.add(jsonEncode({'type': 'auth_ok'}));
            case 'get_config':
              socket.add(
                jsonEncode({
                  'id': message['id'],
                  'type': 'result',
                  'success': true,
                  'result': {'location_name': 'Test Home'},
                }),
              );
            case 'get_states':
              socket.add(
                jsonEncode({
                  'id': message['id'],
                  'type': 'result',
                  'success': true,
                  'result': [
                    {
                      'entity_id': 'vacuum.dreame',
                      'state': 'docked',
                      'attributes': {
                        'friendly_name': 'Dreame',
                        'supported_features': 16384,
                      },
                    },
                  ],
                }),
              );
            case 'subscribe_events':
              socket.add(
                jsonEncode({
                  'id': message['id'],
                  'type': 'result',
                  'success': true,
                  'result': null,
                }),
              );
            case 'vacuum/get_segments':
              socket.add(
                jsonEncode({
                  'id': message['id'],
                  'type': 'result',
                  'success': true,
                  'result': {
                    'segments': [
                      {'id': '1_3', 'name': 'Room 1', 'group': 'Ground floor'},
                      {'id': '1_2', 'name': 'Room 2', 'group': 'Ground floor'},
                    ],
                  },
                }),
              );
          }
        });
      });

      final client = HomeAssistantClient(
        'http://${server.address.address}:${server.port}',
        'test-token',
        httpClient: apiClient,
      );
      addTearDown(client.close);
      await client.connect();

      final vacuum = (await client.fetchVacuums()).single;
      expect(vacuum.supportsAreaCleaning, isTrue);
      final segments = await client.fetchVacuumSegments(vacuum.entityId);
      expect(segments.map((segment) => segment.name), ['Room 1', 'Room 2']);

      await client.cleanVacuumSegments(
        vacuum.entityId,
        segments.map((segment) => segment.id).toList(),
      );

      expect(servicePayload, {
        'entity_id': 'vacuum.dreame',
        'segments': [3, 2],
      });
    },
  );

  test(
    'receives live vacuum state over the Home Assistant WebSocket API',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      final sendEvent = Completer<void>();
      final eventSent = Completer<void>();
      var mapFetches = 0;
      final mapClient = MockClient((request) async {
        expect(request.url.path, '/api/camera_proxy/camera.test_map');
        expect(
          request.headers[HttpHeaders.authorizationHeader],
          'Bearer test-token',
        );
        mapFetches++;
        return http.Response.bytes([mapFetches], HttpStatus.ok);
      });
      server.listen((request) async {
        final socket = await WebSocketTransformer.upgrade(request);
        socket.add(jsonEncode({'type': 'auth_required'}));
        socket.listen((rawMessage) async {
          final message =
              jsonDecode(rawMessage as String) as Map<String, dynamic>;
          switch (message['type']) {
            case 'auth':
              expect(message['access_token'], 'test-token');
              socket.add(
                jsonEncode({'type': 'auth_ok', 'ha_version': '2026.8.0'}),
              );
            case 'get_config':
              socket.add(
                jsonEncode({
                  'id': message['id'],
                  'type': 'result',
                  'success': true,
                  'result': {'location_name': 'Test Home'},
                }),
              );
            case 'get_states':
              socket.add(
                jsonEncode({
                  'id': message['id'],
                  'type': 'result',
                  'success': true,
                  'result': [
                    {
                      'entity_id': 'vacuum.test',
                      'state': 'docked',
                      'attributes': {'friendly_name': 'Test Vacuum'},
                    },
                    {
                      'entity_id': 'sensor.test_battery',
                      'state': '81',
                      'attributes': {'device_class': 'battery'},
                    },
                    {
                      'entity_id': 'camera.test_map',
                      'state': 'streaming',
                      'attributes': {'friendly_name': 'Test Vacuum Map'},
                    },
                  ],
                }),
              );
            case 'subscribe_events':
              socket.add(
                jsonEncode({
                  'id': message['id'],
                  'type': 'result',
                  'success': true,
                  'result': null,
                }),
              );
              if (message['event_type'] != 'state_changed' &&
                  message['event_type'] != 'dreame_vacuum_error') {
                return;
              }
              await sendEvent.future;
              if (message['event_type'] == 'dreame_vacuum_error') {
                socket.add(
                  jsonEncode({
                    'id': message['id'],
                    'type': 'event',
                    'event': {
                      'event_type': 'dreame_vacuum_error',
                      'data': {
                        'entity_id': 'vacuum.test',
                        'error': 'Left wheel blocked',
                        'code': 3,
                      },
                    },
                  }),
                );
                eventSent.complete();
                return;
              }
              socket.add(
                jsonEncode({
                  'id': message['id'],
                  'type': 'event',
                  'event': {
                    'event_type': 'state_changed',
                    'data': {
                      'entity_id': 'vacuum.test',
                      'new_state': {
                        'entity_id': 'vacuum.test',
                        'state': 'cleaning',
                        'attributes': {'friendly_name': 'Test Vacuum'},
                      },
                    },
                  },
                }),
              );
              socket.add(
                jsonEncode({
                  'id': message['id'],
                  'type': 'event',
                  'event': {
                    'event_type': 'state_changed',
                    'data': {
                      'entity_id': 'camera.test_map',
                      'new_state': {
                        'entity_id': 'camera.test_map',
                        'state': 'streaming',
                        'attributes': {
                          'friendly_name': 'Test Vacuum Map',
                          'entity_picture':
                              '/api/camera_proxy/camera.test_map?token=new',
                        },
                      },
                    },
                  },
                }),
              );
          }
        });
      });

      final client = HomeAssistantClient(
        'http://${server.address.address}:${server.port}',
        'test-token',
        httpClient: mapClient,
      );
      addTearDown(client.close);
      expect(await client.connect(), 'Test Home');
      final initial = await client.fetchVacuums();
      expect(initial.single.state, 'docked');
      expect(initial.single.battery, 81);
      expect(initial.single.mapImage, [1]);

      final liveUpdate = client.vacuumUpdates.firstWhere(
        (vacuums) =>
            vacuums.single.state == 'cleaning' &&
            vacuums.single.mapImage?.first == 2,
      );
      final notification = client.notificationUpdates.first;
      sendEvent.complete();
      await eventSent.future;
      final updated = (await liveUpdate).single;
      expect(updated.state, 'cleaning');
      expect(updated.mapImage, [2]);
      expect((await notification).body, 'Left wheel blocked');
    },
  );

  test('reconnects when an open WebSocket stops responding', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    var connections = 0;

    server.listen((request) async {
      final connection = ++connections;
      final socket = await WebSocketTransformer.upgrade(request);
      socket.add(jsonEncode({'type': 'auth_required'}));
      socket.listen((rawMessage) {
        final message =
            jsonDecode(rawMessage as String) as Map<String, dynamic>;
        switch (message['type']) {
          case 'auth':
            socket.add(jsonEncode({'type': 'auth_ok'}));
          case 'get_config':
            socket.add(
              jsonEncode({
                'id': message['id'],
                'type': 'result',
                'success': true,
                'result': {'location_name': 'Test Home'},
              }),
            );
          case 'get_states':
            socket.add(
              jsonEncode({
                'id': message['id'],
                'type': 'result',
                'success': true,
                'result': [
                  {
                    'entity_id': 'vacuum.test',
                    'state': connection == 1 ? 'docked' : 'cleaning',
                    'attributes': {'friendly_name': 'Test Vacuum'},
                  },
                ],
              }),
            );
          case 'subscribe_events':
            socket.add(
              jsonEncode({
                'id': message['id'],
                'type': 'result',
                'success': true,
                'result': null,
              }),
            );
          case 'ping':
            // Simulate a half-open first socket: it accepts writes but never
            // answers. The replacement connection responds normally.
            if (connection > 1) {
              socket.add(jsonEncode({'id': message['id'], 'type': 'pong'}));
            }
        }
      });
    });

    final client = HomeAssistantClient(
      'http://${server.address.address}:${server.port}',
      'test-token',
      heartbeatInterval: const Duration(milliseconds: 20),
      heartbeatTimeout: const Duration(milliseconds: 20),
    );
    addTearDown(client.close);
    final reconnecting = client.connectionUpdates.firstWhere(
      (status) => status == HomeAssistantConnectionStatus.reconnecting,
    );
    final cleaning = client.vacuumUpdates.firstWhere(
      (vacuums) => vacuums.single.state == 'cleaning',
    );

    await client.connect();
    expect((await client.fetchVacuums()).single.state, 'docked');
    await reconnecting.timeout(const Duration(seconds: 1));
    expect(
      (await cleaning.timeout(const Duration(seconds: 5))).single.state,
      'cleaning',
    );
    expect(connections, 2);
    expect(client.connectionStatus, HomeAssistantConnectionStatus.connected);
  });

  test(
    'retries again when a WebSocket reconnect handshake times out',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      var requests = 0;

      server.listen((request) async {
        final requestNumber = ++requests;
        if (requestNumber == 2) {
          // Leave this upgrade request hanging, as can happen when a network
          // disappears without immediately rejecting existing connections.
          return;
        }
        final socket = await WebSocketTransformer.upgrade(request);
        socket.add(jsonEncode({'type': 'auth_required'}));
        socket.listen((rawMessage) {
          final message =
              jsonDecode(rawMessage as String) as Map<String, dynamic>;
          switch (message['type']) {
            case 'auth':
              socket.add(jsonEncode({'type': 'auth_ok'}));
            case 'get_config':
              socket.add(
                jsonEncode({
                  'id': message['id'],
                  'type': 'result',
                  'success': true,
                  'result': {'location_name': 'Test Home'},
                }),
              );
            case 'get_states':
              socket.add(
                jsonEncode({
                  'id': message['id'],
                  'type': 'result',
                  'success': true,
                  'result': [
                    {
                      'entity_id': 'vacuum.test',
                      'state': requestNumber == 1 ? 'docked' : 'cleaning',
                      'attributes': {'friendly_name': 'Test Vacuum'},
                    },
                  ],
                }),
              );
            case 'subscribe_events':
              socket.add(
                jsonEncode({
                  'id': message['id'],
                  'type': 'result',
                  'success': true,
                  'result': null,
                }),
              );
            case 'ping':
              if (requestNumber > 1) {
                socket.add(jsonEncode({'id': message['id'], 'type': 'pong'}));
              }
          }
        });
      });

      final client = HomeAssistantClient(
        'http://${server.address.address}:${server.port}',
        'test-token',
        heartbeatInterval: const Duration(milliseconds: 20),
        heartbeatTimeout: const Duration(milliseconds: 20),
        connectionTimeout: const Duration(milliseconds: 50),
        reconnectDelays: const [Duration(milliseconds: 10)],
      );
      addTearDown(client.close);
      final cleaning = client.vacuumUpdates.firstWhere(
        (vacuums) => vacuums.single.state == 'cleaning',
      );

      await client.connect();
      expect(
        (await cleaning.timeout(const Duration(seconds: 2))).single.state,
        'cleaning',
      );
      expect(requests, 3);
      expect(client.connectionStatus, HomeAssistantConnectionStatus.connected);
    },
  );

  testWidgets('mobile dashboard controls open and labels stay on one line', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const ScrubbyApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Explore with demo home'));
    await tester.pumpAndSettle();
    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpAndSettle();

    final greetingFinder = find.byWidgetPredicate(
      (widget) => widget is Text && widget.data?.startsWith('Good ') == true,
    );
    final greeting = tester.widget<Text>(greetingFinder);
    expect(greeting.maxLines, 1);

    await tester.ensureVisible(find.text('Suction'));
    await tester.tap(find.text('Suction'));
    await tester.pumpAndSettle();
    expect(find.text('Suction power'), findsOneWidget);
    expect(find.text('Turbo'), findsOneWidget);
    await tester.tap(find.text('Turbo'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Travelled'));
    await tester.tap(find.text('Travelled'));
    await tester.pumpAndSettle();
    expect(find.text('Cleaning history'), findsOneWidget);
    expect(find.text('Distance by day'), findsOneWidget);
    Navigator.of(tester.element(find.text('Cleaning history'))).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Today at a glance'));
    await tester.pumpAndSettle();
    expect(find.text('Cleaning activity'), findsOneWidget);
    Navigator.of(tester.element(find.text('Cleaning history'))).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Rooms').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Cleaning power'));
    final turbo = tester.widget<Text>(find.text('Turbo'));
    expect(turbo.maxLines, 1);
    expect(turbo.softWrap, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    're-labelling a mapped room replaces its name on manual controls',
    (WidgetTester tester) async {
      final state = AppState(secureStorage: const _FakeSecureStorage())
        ..startDemo();
      final originalCount = state.mapRoomLabels.length;
      final kitchen = state.mapRoomLabels.first;

      await state.addMapRoomLabel('Galley', kitchen.segmentId);

      expect(state.mapRoomLabels, hasLength(originalCount));
      expect(state.mapRoomLabels.first.name, 'Galley');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: RoomsPage(state: state)),
        ),
      );

      expect(find.text('Galley'), findsOneWidget);
      expect(find.text('Kitchen'), findsNothing);
    },
  );

  testWidgets(
    'saving a map room label keeps its controller alive through dismissal',
    (WidgetTester tester) async {
      final state = AppState(secureStorage: const _FakeSecureStorage())
        ..startDemo();
      state.mapRoomLabels.clear();
      state.vacuums = [
        VacuumEntity(
          entityId: state.vacuums[0].entityId,
          name: state.vacuums[0].name,
          state: state.vacuums[0].state,
          battery: state.vacuums[0].battery,
          mapImage: base64Decode(
            'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
          ),
        ),
      ];
      await tester.binding.setSurfaceSize(const Size(800, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HomePage(state: state, onOpenSettings: () {}),
          ),
        ),
      );

      expect(find.byTooltip('Name a room'), findsNothing);
      expect(find.byTooltip('Zoom in'), findsNothing);
      await tester.tap(find.bySemanticsLabel('Open map full screen'));
      await tester.pumpAndSettle();

      expect(find.text('Orbit map'), findsOneWidget);
      expect(find.byTooltip('Zoom in'), findsOneWidget);
      await tester.tap(find.byTooltip('Name a room'));
      await tester.pumpAndSettle();
      expect(tester.testTextInput.hasAnyClients, isFalse);
      await tester.enterText(find.bySemanticsLabel('Display name'), 'Kitchen');
      await tester.tap(find.text('Add label'));
      await tester.pumpAndSettle();

      expect(state.mapRoomLabels.single.name, 'Kitchen');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('asks for confirmation before logging out', (
    WidgetTester tester,
  ) async {
    final state = AppState(secureStorage: const _FakeSecureStorage())
      ..startDemo();
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(home: DashboardShell(state: state)));

    await tester.tap(find.byTooltip('Disconnect'));
    await tester.pumpAndSettle();

    expect(find.text('Log out?'), findsOneWidget);
    expect(
      find.text(
        'You’ll need to reconnect to Home Assistant to use Scrubby again.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Today at a glance'), findsOneWidget);

    await tester.tap(find.byTooltip('Disconnect'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();
    expect(state.vacuums, isEmpty);
  });

  testWidgets('swiping switches dashboard tabs', (WidgetTester tester) async {
    final state = AppState(secureStorage: const _FakeSecureStorage())
      ..startDemo();
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(home: DashboardShell(state: state)));
    final content = find.byKey(const ValueKey('dashboard-page-content'));

    await tester.fling(content, const Offset(-400, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text('Cleaning rhythm'), findsOneWidget);

    await tester.fling(content, const Offset(400, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text('Today at a glance'), findsOneWidget);

    await tester.fling(content, const Offset(400, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text('Today at a glance'), findsOneWidget);
  });

  testWidgets('desktop dashboard lays out all tab pages', (
    WidgetTester tester,
  ) async {
    final state = AppState(secureStorage: const _FakeSecureStorage())
      ..startDemo();
    await tester.binding.setSurfaceSize(const Size(1200, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(home: DashboardShell(state: state)));

    expect(find.text('Today at a glance'), findsOneWidget);
  });

  testWidgets('opens vacuum settings from the home vacuum card', (
    WidgetTester tester,
  ) async {
    final state = AppState(secureStorage: const _FakeSecureStorage())
      ..startDemo();
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(home: DashboardShell(state: state)));

    expect(find.text('Settings'), findsNothing);
    expect(find.text('Tap for settings'), findsOneWidget);

    await tester.tap(find.text(state.vacuum.name));
    await tester.pumpAndSettle();

    expect(find.text('${state.vacuum.name} settings'), findsOneWidget);
    expect(find.text('Carpet cleaning mode'), findsOneWidget);
  });

  testWidgets('shows and updates Dreame carpet settings', (
    WidgetTester tester,
  ) async {
    final state = AppState(secureStorage: const _FakeSecureStorage())
      ..startDemo();
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SettingsPage(state: state)),
      ),
    );

    expect(find.text('Carpets'), findsOneWidget);
    expect(find.text('Carpet cleaning mode'), findsOneWidget);
    expect(find.text('Clean carpets first'), findsOneWidget);
    expect(find.text('Carpet boost'), findsOneWidget);

    await tester.tap(find.text('Intensive'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Adaptation').last);
    await tester.pumpAndSettle();

    final carpetMode = state.vacuumSettings.firstWhere(
      (setting) => setting.name == 'Carpet cleaning mode',
    );
    expect(carpetMode.value, 'Adaptation');

    final cleanFirstRow = find
        .ancestor(
          of: find.text('Clean carpets first'),
          matching: find.byType(Row),
        )
        .first;
    await tester.tap(
      find.descendant(of: cleanFirstRow, matching: find.byType(Switch)),
    );
    await tester.pumpAndSettle();
    expect(
      state.vacuumSettings
          .firstWhere((setting) => setting.name == 'Clean carpets first')
          .enabled,
      isFalse,
    );
  });

  testWidgets('hides unavailable settings in a collapsed section', (
    WidgetTester tester,
  ) async {
    final state = _SettingsTestState([
      const VacuumSetting(
        entityId: 'switch.orbit_carpet_boost',
        name: 'Carpet boost',
        kind: VacuumSettingKind.toggle,
        value: 'on',
      ),
      const VacuumSetting(
        entityId: 'switch.orbit_off_peak_charging',
        name: 'Off-peak charging',
        kind: VacuumSettingKind.toggle,
        value: 'unavailable',
        available: false,
      ),
    ])..startDemo();
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SettingsPage(state: state)),
      ),
    );

    expect(find.text('Carpet boost'), findsOneWidget);
    expect(find.text('Unavailable settings (1)'), findsOneWidget);
    expect(find.text('Off-peak charging'), findsNothing);

    await tester.tap(find.text('Unavailable settings (1)'));
    await tester.pumpAndSettle();

    expect(find.text('Off-peak charging'), findsOneWidget);
    expect(find.text('Currently unavailable'), findsOneWidget);
  });

  testWidgets('searches settings and clears the query', (
    WidgetTester tester,
  ) async {
    final state = _SettingsTestState([
      const VacuumSetting(
        entityId: 'switch.orbit_carpet_boost',
        name: 'Carpet boost',
        kind: VacuumSettingKind.toggle,
        value: 'on',
      ),
      const VacuumSetting(
        entityId: 'select.orbit_water_volume',
        name: 'Water volume',
        kind: VacuumSettingKind.select,
        value: 'Medium',
        options: ['Low', 'Medium', 'High'],
      ),
    ])..startDemo();
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SettingsPage(state: state)),
      ),
    );

    final searchField = find.bySemanticsLabel('Search settings');
    expect(searchField, findsOneWidget);
    await tester.enterText(searchField, 'water');
    await tester.pump();

    expect(find.text('Water volume'), findsOneWidget);
    expect(find.text('Carpet boost'), findsNothing);

    await tester.enterText(searchField, 'missing');
    await tester.pump();
    expect(find.text('No settings found'), findsOneWidget);
    expect(find.text('Nothing matches “missing”.'), findsOneWidget);

    await tester.tap(find.text('Clear search').last);
    await tester.pump();
    expect(find.text('Water volume'), findsOneWidget);
    expect(find.text('Carpet boost'), findsOneWidget);
  });
}

class _DelayedVacuumClient extends HomeAssistantClient {
  _DelayedVacuumClient()
    : super(
        'http://homeassistant.local:8123',
        'test-token',
        httpClient: MockClient((_) async => http.Response('[]', HttpStatus.ok)),
      );

  final serviceStarted = Completer<void>();
  final releaseService = Completer<void>();
  final roomsStarted = Completer<void>();
  final releaseRooms = Completer<void>();
  final settingWriteStarted = Completer<void>();
  final releaseSettingWrite = Completer<void>();
  final scheduleToggleStarted = Completer<void>();
  final releaseScheduleToggle = Completer<void>();
  final Map<String, Completer<List<VacuumSetting>>> settingFetches = {};
  String? serviceEntityId;
  String? roomsEntityId;

  @override
  Future<void> callVacuumService(
    String service,
    String entityId, {
    Map<String, Object?> data = const {},
  }) async {
    serviceEntityId = entityId;
    if (!serviceStarted.isCompleted) serviceStarted.complete();
    await releaseService.future;
  }

  @override
  Future<void> cleanVacuumSegments(
    String entityId,
    List<String> segmentIds,
  ) async {
    roomsEntityId = entityId;
    if (!roomsStarted.isCompleted) roomsStarted.complete();
    await releaseRooms.future;
  }

  @override
  Future<List<VacuumSetting>> fetchVacuumSettings(String vacuumEntityId) {
    return settingFetches
        .putIfAbsent(vacuumEntityId, Completer<List<VacuumSetting>>.new)
        .future;
  }

  @override
  Future<void> setVacuumSetting(VacuumSetting setting, Object? value) async {
    if (!settingWriteStarted.isCompleted) settingWriteStarted.complete();
    await releaseSettingWrite.future;
  }

  @override
  Future<void> setScrubbyScheduleEnabled(String entityId, bool enabled) async {
    if (!scheduleToggleStarted.isCompleted) scheduleToggleStarted.complete();
    await releaseScheduleToggle.future;
    throw Exception('toggle failed');
  }
}

class _SettingsTestState extends AppState {
  _SettingsTestState(this.settings)
    : super(secureStorage: const _FakeSecureStorage());

  final List<VacuumSetting> settings;

  @override
  List<VacuumSetting> get vacuumSettings => settings;
}

class _FakeSecureStorage extends FlutterSecureStorage {
  const _FakeSecureStorage();

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {}
}
