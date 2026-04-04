import 'package:flutter_cockpit_devtools/src/application/cockpit_json_key_normalizer.dart';
import 'package:test/test.dart';

void main() {
  test('cockpitCompactJsonValue omits null fields recursively from maps', () {
    final normalized = cockpitCompactJsonValue(<String, Object?>{
      'sessionId': 'session-1',
      'current_route_name': null,
      'snapshot': <String, Object?>{
        'route_name': '/home',
        'diagnostics': null,
      },
      'entries': <Object?>[
        <String, Object?>{
          'label': 'Inbox',
          'tooltip': null,
        },
      ],
    }) as Map<String, Object?>;

    expect(normalized['sessionId'], 'session-1');
    expect(normalized.containsKey('current_route_name'), isFalse);
    expect(normalized['snapshot'], <String, Object?>{
      'route_name': '/home',
    });
    expect(normalized['entries'], <Object?>[
      <String, Object?>{'label': 'Inbox'},
    ]);
  });

  test('pretty and compact json helpers preserve existing key casing', () {
    final payload = <String, Object?>{
      'sessionHandle': <String, Object?>{
        'deviceId': 'emulator-5554',
        'base_url': 'http://127.0.0.1:58421',
        'nullField': null,
      },
    };

    expect(
      cockpitCompactJsonText(payload),
      '{"sessionHandle":{"deviceId":"emulator-5554","base_url":"http://127.0.0.1:58421"}}',
    );
    expect(
      cockpitPrettyJsonText(payload),
      '{\n'
      '  "sessionHandle": {\n'
      '    "deviceId": "emulator-5554",\n'
      '    "base_url": "http://127.0.0.1:58421"\n'
      '  }\n'
      '}',
    );
  });
}
