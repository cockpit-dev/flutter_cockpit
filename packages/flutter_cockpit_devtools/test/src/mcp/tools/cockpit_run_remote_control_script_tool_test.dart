import 'dart:io';

import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_application_service_exception.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_bundle_artifact_paths.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_run_remote_control_script_service.dart';
import 'package:flutter_cockpit_devtools/src/mcp/cockpit_mcp_error.dart';
import 'package:flutter_cockpit_devtools/src/mcp/tools/cockpit_run_remote_control_script_tool.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test(
    'run tool maps a structured script into the run service and returns bundle metadata',
    () async {
      CockpitRunRemoteControlScriptRequest? capturedRequest;
      final bundleDir = Directory.systemTemp.createTempSync(
        'cockpit_run_remote_control_script_tool',
      );
      addTearDown(() async {
        if (bundleDir.existsSync()) {
          await bundleDir.delete(recursive: true);
        }
      });

      final tool = CockpitRunRemoteControlScriptTool(
        run: (request) async {
          capturedRequest = request;
          return CockpitRunRemoteControlScriptResult(
            sessionHandle: null,
            bundleDir: bundleDir,
            manifest: CockpitRunManifest(
              sessionId: 'run-tool-session',
              taskId: 'run-tool-task',
              platform: 'android',
              status: CockpitTaskStatus.completed,
              startedAt: DateTime.utc(2026, 3, 21, 0, 0),
              finishedAt: DateTime.utc(2026, 3, 21, 0, 5),
              commandCount: 2,
              screenshotCount: 1,
              recordingCount: 1,
              deliveryArtifactsReady: true,
              deliveryVideoReady: true,
            ),
            handoff: const <String, Object?>{'status': 'completed'},
            delivery: const <String, Object?>{
              'primaryScreenshotRef': 'screenshots/acceptance.png',
              'primaryRecordingRef': 'recordings/acceptance.mp4',
            },
            artifactPaths: CockpitBundleArtifactPaths(
              primaryScreenshotPath: p.join(
                bundleDir.path,
                'screenshots',
                'acceptance.png',
              ),
              primaryRecordingPath: p.join(
                bundleDir.path,
                'recordings',
                'acceptance.mp4',
              ),
            ),
          );
        },
      );

      final result = await tool.call(<String, Object?>{
        'baseUrl': 'http://127.0.0.1:58421',
        'outputRoot': '/tmp/out',
        'persistScriptPath': '/tmp/replay_script.json',
        'script': <String, Object?>{
          'sessionId': 'run-tool-session',
          'taskId': 'run-tool-task',
          'platform': 'android',
          'commands': <Map<String, Object?>>[
            CockpitCommand(
              commandId: 'tap-open',
              commandType: CockpitCommandType.tap,
              locator: const CockpitLocator(
                kind: CockpitLocatorKind.cockpitId,
                value: 'open_form_button',
              ),
            ).toJson(),
          ],
          'failFast': true,
        },
      });

      expect(capturedRequest?.outputRoot, '/tmp/out');
      expect(capturedRequest?.baseUri?.toString(), 'http://127.0.0.1:58421');
      expect(capturedRequest?.androidDeviceId, isNull);
      expect(capturedRequest?.portForwardingHandled, isTrue);
      expect(capturedRequest?.script.sessionId, 'run-tool-session');
      expect(capturedRequest?.script.environment, isNull);

      final structuredContent =
          result['structuredContent'] as Map<String, Object?>;
      expect(structuredContent['bundleDir'], bundleDir.path);
      expect(
        (structuredContent['artifactPaths']
            as Map<String, Object?>)['primaryRecordingPath'],
        p.join(bundleDir.path, 'recordings', 'acceptance.mp4'),
      );
    },
  );

  test('run tool maps service errors into MCP errors', () async {
    final tool = CockpitRunRemoteControlScriptTool(
      run: (_) async => throw const CockpitApplicationServiceException(
        code: 'bundleWriteFailed',
        message: 'Bundle could not be written.',
      ),
    );

    expect(
      () => tool.call(<String, Object?>{
        'baseUrl': 'http://127.0.0.1:58421',
        'outputRoot': '/tmp/out',
        'script': <String, Object?>{
          'sessionId': 'run-tool-session',
          'taskId': 'run-tool-task',
          'platform': 'android',
          'environment': const CockpitEnvironment(
            platform: 'android',
            flutterVersion: '3.38.9',
            dartVersion: '3.10.8',
          ).toJson(),
          'commands': const <Map<String, Object?>>[],
          'failFast': true,
        },
      }),
      throwsA(
        isA<CockpitMcpError>().having(
          (error) => error.data['serviceCode'],
          'serviceCode',
          'bundleWriteFailed',
        ),
      ),
    );
  });

  test('run tool treats failed bundle manifests as MCP errors', () async {
    final bundleDir = Directory.systemTemp.createTempSync(
      'cockpit_run_remote_control_script_tool_failed',
    );
    addTearDown(() async {
      if (bundleDir.existsSync()) {
        await bundleDir.delete(recursive: true);
      }
    });

    final tool = CockpitRunRemoteControlScriptTool(
      run: (_) async => CockpitRunRemoteControlScriptResult(
        sessionHandle: null,
        bundleDir: bundleDir,
        manifest: CockpitRunManifest(
          sessionId: 'run-tool-session',
          taskId: 'run-tool-task',
          platform: 'android',
          status: CockpitTaskStatus.failed,
          startedAt: DateTime.utc(2026, 3, 21, 0, 0),
          finishedAt: DateTime.utc(2026, 3, 21, 0, 5),
          failureSummary: 'Expected text was not visible.',
        ),
        handoff: const <String, Object?>{},
        delivery: const <String, Object?>{},
        artifactPaths: CockpitBundleArtifactPaths(),
      ),
    );

    expect(
      () => tool.call(<String, Object?>{
        'baseUrl': 'http://127.0.0.1:58421',
        'outputRoot': '/tmp/out',
        'script': <String, Object?>{
          'sessionId': 'run-tool-session',
          'taskId': 'run-tool-task',
          'platform': 'android',
          'environment': const CockpitEnvironment(
            platform: 'android',
            flutterVersion: '3.38.9',
            dartVersion: '3.10.8',
          ).toJson(),
          'commands': const <Map<String, Object?>>[],
          'failFast': true,
        },
      }),
      throwsA(
        isA<CockpitMcpError>()
            .having((error) => error.code, 'code', -32000)
            .having(
              (error) => error.data['failureSummary'],
              'failureSummary',
              'Expected text was not visible.',
            ),
      ),
    );
  });
}
