import 'package:cockpit_protocol/cockpit_protocol.dart';
import 'package:cockpit/src/application/cockpit_read_network_service.dart';
import 'package:cockpit/src/application/cockpit_session_registry.dart';
import 'package:cockpit/src/mcp/tools/cockpit_read_network_tool.dart';
import 'package:test/test.dart';

void main() {
  test(
    'read_network passes app-first network arguments through to the service',
    () async {
      CockpitReadNetworkRequest? capturedRequest;
      final tool = CockpitReadNetworkTool(
        service: CockpitReadNetworkService(registry: CockpitSessionRegistry()),
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
        'appId': 'dev.example.app',
        'appJson': '/tmp/app.json',
        'baseUrl': 'http://127.0.0.1:47331',
        'androidDeviceId': 'emulator-5554',
        'maxEntries': 8,
        'maxEndpointSummaries': 3,
        'includeEntries': true,
        'method': 'GET',
        'uriContains': '/api',
        'statusCodeAtLeast': 400,
        'onlyFailures': true,
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
    },
  );
}
