import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_read_network_service.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_session_registry.dart';
import 'package:flutter_cockpit_devtools/src/mcp/tools/cockpit_read_network_tool.dart';
import 'package:test/test.dart';

void main() {
  test('read_network passes app-first network arguments through to the service',
      () async {
    CockpitReadNetworkRequest? capturedRequest;
    final tool = CockpitReadNetworkTool(
      service: CockpitReadNetworkService(
        registry: CockpitSessionRegistry(),
      ),
      read: (request) async {
        capturedRequest = request;
        return CockpitReadNetworkResult(
          appId: 'dev.example.app',
          source: 'app_snapshot',
          available: true,
          routeName: '/inbox',
          summary: const CockpitReadNetworkSummary(
            totalEntryCount: 3,
            failureCount: 1,
            capturedEntryCount: 5,
            inFlightCount: 0,
            truncated: false,
            query: CockpitNetworkQuery(
              method: 'GET',
              uriContains: '/api',
              onlyFailures: true,
            ),
          ),
          endpointSummaries: const <CockpitNetworkEndpointSummary>[],
          endpointSummariesTruncated: false,
          recentFailures: const <CockpitNetworkEntry>[],
        );
      },
    );

    final result = await tool.call(<String, Object?>{
      'app_id': 'dev.example.app',
      'app_json': '/tmp/app.json',
      'base_url': 'http://127.0.0.1:47331',
      'android_device_id': 'emulator-5554',
      'max_entries': 8,
      'max_endpoint_summaries': 3,
      'include_entries': true,
      'method': 'GET',
      'uri_contains': '/api',
      'status_code_at_least': 400,
      'only_failures': true,
    });

    expect(capturedRequest?.appId, 'dev.example.app');
    expect(capturedRequest?.appHandlePath, '/tmp/app.json');
    expect(capturedRequest?.baseUri?.toString(), 'http://127.0.0.1:47331');
    expect(capturedRequest?.androidDeviceId, 'emulator-5554');
    expect(capturedRequest?.maxEntries, 8);
    expect(capturedRequest?.maxEndpointSummaries, 3);
    expect(capturedRequest?.includeEntries, isTrue);
    expect(capturedRequest?.method, 'GET');
    expect(capturedRequest?.uriContains, '/api');
    expect(capturedRequest?.statusCodeAtLeast, 400);
    expect(capturedRequest?.onlyFailures, isTrue);
    expect(result['structuredContent'], isA<Map<String, Object?>>());
  });
}
