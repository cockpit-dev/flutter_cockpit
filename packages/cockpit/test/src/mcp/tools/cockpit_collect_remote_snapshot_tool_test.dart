import 'package:flutter_cockpit_protocol/flutter_cockpit_protocol.dart';
import 'package:cockpit/src/application/cockpit_collect_remote_snapshot_service.dart';
import 'package:cockpit/src/mcp/cockpit_mcp_error.dart';
import 'package:cockpit/src/mcp/tools/cockpit_collect_remote_snapshot_tool.dart';
import 'package:cockpit/src/session/cockpit_remote_session_handle.dart';
import 'package:test/test.dart';

void main() {
  test(
    'collect snapshot tool forwards session references and snapshot options',
    () async {
      CockpitCollectRemoteSnapshotRequest? capturedRequest;
      final handle = CockpitRemoteSessionHandle(
        platform: 'ios',
        deviceId: 'simulator',
        projectDir: '/workspace/examples/cockpit_demo',
        target: 'lib/main.dart',
        appId: 'dev.cockpit.cockpit_demo',
        host: '127.0.0.1',
        hostPort: 58421,
        devicePort: 47331,
        baseUrl: 'http://127.0.0.1:58421',
        launchedAt: DateTime.utc(2026, 3, 22, 0, 0),
      );

      final tool = CockpitCollectRemoteSnapshotTool(
        collect: (request) async {
          capturedRequest = request;
          return CockpitCollectRemoteSnapshotResult(
            snapshot: CockpitSnapshot(
              routeName: '/investigate',
              diagnosticLevel: request.options.profile,
            ),
            effectiveOptions: request.options.copyWith(
              emitArtifactWhenLarge: false,
            ),
            warnings: const <String>[
              'Direct remote snapshots do not support downloadable diagnostic artifacts; falling back to inline diagnostics.',
            ],
            sessionHandle: handle,
          );
        },
      );

      final result = await tool.call(<String, Object?>{
        'sessionHandle': handle.toJson(),
        'snapshotOptions': <String, Object?>{
          'profile': 'forensic',
          'includeNetworkActivity': true,
          'includeRuntimeActivity': true,
          'networkQuery': <String, Object?>{
            'method': 'GET',
            'uriContains': '/tasks',
          },
          'runtimeQuery': <String, Object?>{
            'onlyErrors': true,
            'messageContains': 'runtime probe',
          },
          'emitArtifactWhenLarge': true,
        },
        'downloadDiagnosticsArtifacts': true,
      });

      expect(capturedRequest?.sessionHandle?.toJson(), handle.toJson());
      expect(capturedRequest?.options.profile, CockpitSnapshotProfile.forensic);
      expect(capturedRequest?.options.includeNetworkActivity, isTrue);
      expect(capturedRequest?.options.networkQuery.method, 'GET');
      expect(capturedRequest?.options.includeRuntimeActivity, isTrue);
      expect(capturedRequest?.options.runtimeQuery.onlyErrors, isTrue);
      expect(
        capturedRequest?.options.runtimeQuery.messageContains,
        'runtime probe',
      );
      expect(capturedRequest?.options.emitArtifactWhenLarge, isTrue);
      expect(capturedRequest?.downloadDiagnosticsArtifacts, isTrue);

      final structuredContent =
          result['structuredContent'] as Map<String, Object?>;
      expect(
        (structuredContent['snapshot'] as Map<String, Object?>)['routeName'],
        '/investigate',
      );
      expect(
        (structuredContent['warnings'] as List<Object?>).single,
        contains('inline diagnostics'),
      );
    },
  );

  test('collect snapshot tool maps service errors into MCP errors', () async {
    final tool = CockpitCollectRemoteSnapshotTool(
      collect: (_) async => throw const CockpitApplicationServiceException(
        code: 'missingSessionReference',
        message: 'Session reference is required.',
      ),
    );

    expect(
      () => tool.call(const <String, Object?>{}),
      throwsA(
        isA<CockpitMcpError>().having(
          (error) => error.data['serviceCode'],
          'serviceCode',
          'missingSessionReference',
        ),
      ),
    );
  });

  test(
    'collect snapshot tool leaves diagnostics artifacts deferred by default',
    () async {
      CockpitCollectRemoteSnapshotRequest? capturedRequest;
      final tool = CockpitCollectRemoteSnapshotTool(
        collect: (request) async {
          capturedRequest = request;
          return CockpitCollectRemoteSnapshotResult(
            snapshot: CockpitSnapshot(
              routeName: '/investigate',
              diagnosticLevel: request.options.profile,
            ),
            effectiveOptions: request.options,
          );
        },
      );

      await tool.call(const <String, Object?>{
        'snapshotOptions': <String, Object?>{
          'profile': 'forensic',
          'emitArtifactWhenLarge': true,
        },
      });

      expect(capturedRequest?.options.emitArtifactWhenLarge, isTrue);
      expect(capturedRequest?.downloadDiagnosticsArtifacts, isFalse);
    },
  );
}
