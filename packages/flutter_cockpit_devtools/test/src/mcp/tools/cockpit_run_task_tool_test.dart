import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_application_service_exception.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_bundle_artifact_paths.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_read_task_bundle_summary_service.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_run_task_service.dart';
import 'package:flutter_cockpit_devtools/src/mcp/cockpit_mcp_error.dart';
import 'package:flutter_cockpit_devtools/src/mcp/tools/cockpit_run_task_tool.dart';
import 'package:test/test.dart';

void main() {
  test(
    'run_task tool maps orchestration input and returns structured summary content',
    () async {
      CockpitRunTaskRequest? capturedRequest;
      final tool = CockpitRunTaskTool(
        runTask: (request) async {
          capturedRequest = request;
          return CockpitRunTaskResult(
            classification: CockpitRunTaskClassification.completed,
            recommendedNextStep: 'delivery_ready',
            bundleSummary: CockpitReadTaskBundleSummaryResult(
              bundleDir: '/tmp/out/run-task',
              manifest: CockpitRunManifest(
                sessionId: 'mcp-run-task-session',
                taskId: 'mcp-run-task-id',
                platform: 'android',
                status: CockpitTaskStatus.completed,
                startedAt: DateTime.utc(2026, 3, 21, 0, 0),
                finishedAt: DateTime.utc(2026, 3, 21, 0, 5),
                deliveryArtifactsReady: true,
              ),
              handoff: const <String, Object?>{'status': 'completed'},
              delivery: const <String, Object?>{
                'primaryScreenshotRef': 'screenshots/acceptance.png',
                'primaryRecordingRef': 'recordings/acceptance.mp4',
                'deliveryKeyframesReady': true,
                'keyframeCoverage': <String, Object?>{
                  'isReady': true,
                  'hasEarlyCoverage': true,
                  'hasMidCoverage': true,
                  'hasLateCoverage': true,
                },
                'keyframes': <Map<String, Object?>>[
                  <String, Object?>{
                    'ref': 'keyframes/acceptance_tail.png',
                    'label': 'tail_consistency',
                    'offsetMs': 3900,
                  },
                ],
              },
              acceptanceMarkdown: '# Acceptance',
              artifactPaths: CockpitBundleArtifactPaths(
                primaryScreenshotPath:
                    '/tmp/out/run-task/screenshots/acceptance.png',
                primaryRecordingPath:
                    '/tmp/out/run-task/recordings/acceptance.mp4',
                keyframePaths: const <String>[
                  '/tmp/out/run-task/keyframes/acceptance_tail.png',
                ],
              ),
              evidenceSummary: const <String, Object?>{
                'status': 'completed',
                'commandCount': 1,
                'screenshotCount': 1,
                'recordingCount': 0,
                'failureCount': 0,
                'keyframeCount': 1,
              },
              diagnosticsArtifactPaths: const <String>[
                '/tmp/out/run-task/diagnostics/failure_snapshot.json',
              ],
              runtimeSummary: const CockpitBundleRuntimeSummary(
                totalEntryCount: 2,
                errorCount: 1,
                warningCount: 0,
                truncated: false,
              ),
            ),
          );
        },
      );

      final result = await tool.call(<String, Object?>{
        'launch': <String, Object?>{
          'projectDir': '/workspace/examples/cockpit_demo',
          'target': 'lib/main.dart',
          'platform': 'android',
          'deviceId': 'emulator-5554',
          'sessionPort': 47331,
        },
        'script': <String, Object?>{
          'sessionId': 'mcp-run-task-session',
          'taskId': 'mcp-run-task-id',
          'platform': 'android',
          'commands': const <Map<String, Object?>>[],
          'failFast': true,
        },
        'output_root': '/tmp/out',
        'baseline': const <String, Object?>{
          'captureScreenshot': true,
          'screenshotName': 'baseline',
        },
        'requirements': const <String, Object?>{
          'requireScreenshotEvidence': true,
        },
      });

      expect(capturedRequest?.launch?.deviceId, 'emulator-5554');
      expect(capturedRequest?.baseline.screenshotName, 'baseline');
      expect(capturedRequest?.script.environment, isNull);
      final structuredContent =
          result['structuredContent'] as Map<String, Object?>;
      expect(structuredContent['classification'], 'completed');
      final bundleSummary =
          structuredContent['bundle_summary'] as Map<String, Object?>;
      expect(bundleSummary['bundle_dir'], '/tmp/out/run-task');
      expect(
        (bundleSummary['runtime_summary']
            as Map<String, Object?>)['error_count'],
        1,
      );
      final evidence = bundleSummary['evidence'] as Map<String, Object?>;
      expect(
        evidence['primary_recording_path'],
        '/tmp/out/run-task/recordings/acceptance.mp4',
      );
      expect(evidence['delivery_keyframes_ready'], isTrue);
      expect((evidence['keyframes'] as List<Object?>).single, <String, Object?>{
        'ref': 'keyframes/acceptance_tail.png',
        'path': '/tmp/out/run-task/keyframes/acceptance_tail.png',
        'label': 'tail_consistency',
        'offset_ms': 3900,
        'linked_screenshot_ref': null,
        'linked_screenshot_path': null,
      });
    },
  );

  test('run_task tool maps service errors into MCP errors', () async {
    final tool = CockpitRunTaskTool(
      runTask: (_) async => throw const CockpitApplicationServiceException(
        code: 'invalidBundleJson',
        message: 'Bundle JSON is invalid.',
      ),
    );

    expect(
      () => tool.call(<String, Object?>{
        'script': <String, Object?>{
          'sessionId': 'mcp-run-task-session',
          'taskId': 'mcp-run-task-id',
          'platform': 'android',
          'environment': const CockpitEnvironment(
            platform: 'android',
            flutterVersion: '3.38.9',
            dartVersion: '3.10.8',
          ).toJson(),
          'commands': const <Map<String, Object?>>[],
          'failFast': true,
        },
        'output_root': '/tmp/out',
      }),
      throwsA(
        isA<CockpitMcpError>().having(
          (error) => error.data['serviceCode'],
          'serviceCode',
          'invalidBundleJson',
        ),
      ),
    );
  });
}
