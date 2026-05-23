import 'package:flutter_cockpit_devtools/src/mcp/cockpit_mcp_error.dart';
import 'package:flutter_cockpit_devtools/src/mcp/cockpit_mcp_tool.dart';
import 'package:test/test.dart';

void main() {
  test('cockpitMcpResult preserves canonical lower camel case keys', () {
    final result = cockpitMcpResult(
      text: 'ok',
      structuredContent: const <String, Object?>{
        'sessionHandle': <String, Object?>{
          'appId': 'dev.cockpit.demo',
          'baseUrl': 'http://127.0.0.1:8080',
          'diagnosticsPath': null,
        },
        'linkedScreenshotRef': null,
      },
    );

    expect(result['content'], isNotEmpty);
    expect(result['structuredContent'], <String, Object?>{
      'sessionHandle': <String, Object?>{
        'appId': 'dev.cockpit.demo',
        'baseUrl': 'http://127.0.0.1:8080',
      },
    });
  });

  test('argument errors report canonical field names', () {
    expect(
      () => cockpitReadRequiredString(const <String, Object?>{}, 'bundleDir'),
      throwsA(
        isA<CockpitMcpError>().having(
          (error) => error.data['argument'],
          'argument',
          'bundleDir',
        ),
      ),
    );
  });

  test('argument readers do not accept snake case aliases', () {
    expect(
      () => cockpitReadRequiredString(const <String, Object?>{
        'bundle_dir': '/tmp/out',
      }, 'bundleDir'),
      throwsA(isA<CockpitMcpError>()),
    );
  });

  test('object-list argument errors include the invalid item index', () {
    expect(
      () => cockpitReadRequiredObjectList(const <String, Object?>{
        'commands': <Object?>[
          <String, Object?>{'commandId': 'wait-1'},
          'not-an-object',
        ],
      }, 'commands'),
      throwsA(
        isA<CockpitMcpError>()
            .having((error) => error.data['argument'], 'argument', 'commands')
            .having((error) => error.data['index'], 'index', 1),
      ),
    );
  });
}
