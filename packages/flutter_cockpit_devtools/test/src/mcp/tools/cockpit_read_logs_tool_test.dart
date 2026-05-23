import 'package:flutter_cockpit_devtools/src/application/cockpit_read_logs_service.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_session_registry.dart';
import 'package:flutter_cockpit_devtools/src/mcp/tools/cockpit_read_logs_tool.dart';
import 'package:test/test.dart';

void main() {
  test('read_logs passes app-first log arguments through to the service',
      () async {
    CockpitReadLogsRequest? capturedRequest;
    final tool = CockpitReadLogsTool(
      service: CockpitReadLogsService(registry: CockpitSessionRegistry()),
      read: (request) async {
        capturedRequest = request;
        return const CockpitReadLogsResult(
          appId: 'dev.example.app',
          source: 'app_snapshot',
          available: true,
          lines: <String>['info debugLog: loaded'],
          truncated: false,
        );
      },
    );

    final result = await tool.call(<String, Object?>{
      'appId': 'dev.example.app',
      'appJson': '/tmp/app.json',
      'baseUrl': 'http://127.0.0.1:47331',
      'androidDeviceId': 'emulator-5554',
      'maxLines': 40,
    });

    expect(capturedRequest?.appId, 'dev.example.app');
    expect(capturedRequest?.appHandlePath, '/tmp/app.json');
    expect(capturedRequest?.baseUri?.toString(), 'http://127.0.0.1:47331');
    expect(capturedRequest?.androidDeviceId, 'emulator-5554');
    expect(capturedRequest?.maxLines, 40);
    expect(result['structuredContent'], isA<Map<String, Object?>>());
  });
}
