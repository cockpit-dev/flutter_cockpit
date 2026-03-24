import 'dart:io';

import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_application_service_exception.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_bundle_artifact_paths.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_run_remote_control_script_service.dart';
import 'package:flutter_cockpit_devtools/src/mcp/cockpit_mcp_error.dart';
import 'package:flutter_cockpit_devtools/src/mcp/tools/cockpit_run_remote_control_script_tool.dart';
import 'package:flutter_cockpit_devtools/src/session/cockpit_remote_session_handle.dart';
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

      final handle = CockpitRemoteSessionHandle(
        platform: 'android',
        deviceId: 'emulator-5554',
        projectDir: '/workspace/examples/cockpit_demo',
        target: 'lib/main.dart',
        appId: 'dev.cockpit.cockpit_demo',
        host: '127.0.0.1',
        hostPort: 58421,
        devicePort: 47331,
        baseUrl: 'http://127.0.0.1:58421',
        launchedAt: DateTime.utc(2026, 3, 21, 0, 0),
      );
      final tool = CockpitRunRemoteControlScriptTool(
        run: (request) async {
          capturedRequest = request;
          return CockpitRunRemoteControlScriptResult(
            sessionHandle: handle,
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
        'session_handle': handle.toJson(),
        'output_root': '/tmp/out',
        'persist_script_path': '/tmp/replay_script.json',
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
      expect(capturedRequest?.sessionHandle?.toJson(), handle.toJson());
      expect(capturedRequest?.script.sessionId, 'run-tool-session');
      expect(capturedRequest?.script.environment, isNull);

      final structuredContent =
          result['structuredContent'] as Map<String, Object?>;
      expect(structuredContent['bundle_dir'], bundleDir.path);
      expect(
        (structuredContent['artifact_paths']
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
        'output_root': '/tmp/out',
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
}
