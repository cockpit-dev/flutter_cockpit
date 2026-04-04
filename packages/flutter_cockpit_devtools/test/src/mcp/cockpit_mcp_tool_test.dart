import 'package:flutter_cockpit_devtools/src/mcp/cockpit_mcp_error.dart';
import 'package:flutter_cockpit_devtools/src/mcp/cockpit_mcp_tool.dart';
import 'package:test/test.dart';

void main() {
  test('cockpitMcpResult emits lower camel case keys without null fields', () {
    final result = cockpitMcpResult(
      text: 'ok',
      structuredContent: const <String, Object?>{
        'session_handle': <String, Object?>{
          'app_id': 'dev.cockpit.demo',
          'base_url': 'http://127.0.0.1:8080',
          'diagnostics_path': null,
        },
        'linked_screenshot_ref': null,
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

  test('argument errors report lower camel case field names', () {
    expect(
      () => cockpitReadRequiredString(const <String, Object?>{}, 'bundle_dir'),
      throwsA(
        isA<CockpitMcpError>().having(
          (error) => error.data['argument'],
          'argument',
          'bundleDir',
        ),
      ),
    );
  });
}
