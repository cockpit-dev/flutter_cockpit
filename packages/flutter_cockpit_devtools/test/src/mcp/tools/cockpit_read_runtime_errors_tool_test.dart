import 'package:flutter_cockpit_devtools/src/application/cockpit_read_runtime_errors_service.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_latest_task_store.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_session_registry.dart';
import 'package:flutter_cockpit_devtools/src/mcp/tools/cockpit_read_runtime_errors_tool.dart';
import 'package:test/test.dart';

void main() {
  test('read_errors passes app-first arguments through to the service',
      () async {
    CockpitReadRuntimeErrorsRequest? capturedRequest;
    final tool = CockpitReadRuntimeErrorsTool(
      service: CockpitReadRuntimeErrorsService(
        registry: CockpitSessionRegistry(),
        latestTaskStore: CockpitLatestTaskStore(),
      ),
      read: (request) async {
        capturedRequest = request;
        return const CockpitReadRuntimeErrorsResult(
          appId: 'dev.example.app',
          routeName: '/inbox',
          source: 'app_snapshot',
          errors: <CockpitRuntimeErrorEntry>[
            CockpitRuntimeErrorEntry(
              source: 'app_snapshot',
              message: 'boom',
              kind: 'flutterError',
            ),
          ],
        );
      },
    );

    final result = await tool.call(<String, Object?>{
      'appId': 'dev.example.app',
      'appJson': '/tmp/app.json',
      'baseUrl': 'http://127.0.0.1:47331',
      'androidDeviceId': 'emulator-5554',
      'maxErrors': 8,
      'includeLatestTask': false,
      'includeSessions': false,
    });

    expect(capturedRequest?.appId, 'dev.example.app');
    expect(capturedRequest?.appHandlePath, '/tmp/app.json');
    expect(capturedRequest?.baseUri?.toString(), 'http://127.0.0.1:47331');
    expect(capturedRequest?.androidDeviceId, 'emulator-5554');
    expect(capturedRequest?.maxErrors, 8);
    expect(capturedRequest?.includeLatestTask, isFalse);
    expect(capturedRequest?.includeSessions, isFalse);
    expect(result['structuredContent'], isA<Map<String, Object?>>());
  });
}
