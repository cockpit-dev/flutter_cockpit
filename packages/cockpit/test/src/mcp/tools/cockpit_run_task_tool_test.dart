import 'package:cockpit_protocol/cockpit_protocol.dart';
import 'package:cockpit/src/application/cockpit_application_service_exception.dart';
import 'package:cockpit/src/application/cockpit_bundle_artifact_paths.dart';
import 'package:cockpit/src/application/cockpit_read_task_bundle_summary_service.dart';
import 'package:cockpit/src/application/cockpit_run_task_service.dart';
import 'package:cockpit/src/mcp/cockpit_mcp_error.dart';
import 'package:cockpit/src/mcp/tools/cockpit_run_task_tool.dart';
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
            warnings: const <String>[
              'Automation cleanup failed after task orchestration: stop timeout.',
            ],
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
          'platform': 'android',
          'deviceId': 'emulator-5554',
          'sessionPort': 47331,
        },
        'script': <String, Object?>{
          'sessionId': 'mcp-run-task-session',
          'taskId': 'mcp-run-task-id',
          'platform': 'android',
          'commands': <Map<String, Object?>>[_noopCommandJson()],
          'failFast': true,
        },
        'outputRoot': '/tmp/out',
        'baseline': const <String, Object?>{
          'captureScreenshot': true,
          'screenshotName': 'baseline',
        },
        'requirements': const <String, Object?>{
          'requireScreenshotEvidence': true,
        },
      });

      expect(capturedRequest?.launch?.deviceId, 'emulator-5554');
      expect(capturedRequest?.launch?.target, isNull);
      expect(capturedRequest?.baseline.screenshotName, 'baseline');
      expect(capturedRequest?.script.environment, isNull);
      final structuredContent =
          result['structuredContent'] as Map<String, Object?>;
      expect(structuredContent['classification'], 'completed');
      expect(structuredContent['warnings'], <String>[
        'Automation cleanup failed after task orchestration: stop timeout.',
      ]);
      final bundleSummary =
          structuredContent['bundleSummary'] as Map<String, Object?>;
      expect(bundleSummary['bundleDir'], '/tmp/out/run-task');
      expect(
        (bundleSummary['runtimeSummary'] as Map<String, Object?>)['errorCount'],
        1,
      );
      final evidence = bundleSummary['evidence'] as Map<String, Object?>;
      expect(
        evidence['primaryRecordingPath'],
        '/tmp/out/run-task/recordings/acceptance.mp4',
      );
      expect(evidence['deliveryKeyframesReady'], isTrue);
      expect((evidence['keyframes'] as List<Object?>).single, <String, Object?>{
        'ref': 'keyframes/acceptance_tail.png',
        'path': '/tmp/out/run-task/keyframes/acceptance_tail.png',
        'label': 'tail_consistency',
        'offsetMs': 3900,
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
          'commands': <Map<String, Object?>>[_noopCommandJson()],
          'failFast': true,
        },
        'outputRoot': '/tmp/out',
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

Map<String, Object?> _noopCommandJson() => CockpitCommand(
  commandId: 'assert-noop',
  commandType: CockpitCommandType.assertText,
  parameters: const <String, Object?>{'text': 'Ready'},
).toJson();
