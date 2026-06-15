import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_bundle_artifact_paths.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_read_task_bundle_summary_service.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_run_task_service.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_validate_task_service.dart';
import 'package:flutter_cockpit_devtools/src/mcp/cockpit_mcp_error.dart';
import 'package:flutter_cockpit_devtools/src/mcp/tools/cockpit_validate_task_tool.dart';
import 'package:test/test.dart';

void main() {
  test(
    'validate_task tool maps validation input and returns structured validation content',
    () async {
      CockpitValidateTaskRequest? capturedRequest;
      final tool = CockpitValidateTaskTool(
        validateTask: (request) async {
          capturedRequest = request;
          return CockpitValidateTaskResult(
            classification: CockpitValidationClassification.completed,
            recommendedNextStep: 'delivery_ready',
            warnings: const <String>[
              'Automation cleanup failed after task orchestration: stop timeout.',
            ],
            runTaskResult: CockpitRunTaskResult(
              classification: CockpitRunTaskClassification.completed,
              recommendedNextStep: 'delivery_ready',
            ),
            bundleSummary: CockpitReadTaskBundleSummaryResult(
              bundleDir: '/tmp/out/validate-task',
              manifest: CockpitRunManifest(
                sessionId: 'mcp-validate-task-session',
                taskId: 'mcp-validate-task-id',
                platform: 'android',
                status: CockpitTaskStatus.completed,
                startedAt: DateTime.utc(2026, 3, 21, 0, 0),
                finishedAt: DateTime.utc(2026, 3, 21, 0, 5),
                deliveryArtifactsReady: true,
              ),
              handoff: const <String, Object?>{'status': 'completed'},
              delivery: const <String, Object?>{
                'primaryScreenshotRef': 'screenshots/acceptance.png',
                'deliveryKeyframesReady': true,
                'keyframeCoverage': <String, Object?>{
                  'isReady': true,
                  'hasEarlyCoverage': true,
                  'hasMidCoverage': true,
                  'hasLateCoverage': true,
                },
              },
              acceptanceMarkdown: '# Acceptance',
              artifactPaths: CockpitBundleArtifactPaths(
                primaryScreenshotPath:
                    '/tmp/out/validate-task/screenshots/acceptance.png',
                keyframePaths: const <String>[
                  '/tmp/out/validate-task/keyframes/acceptance_midpoint.png',
                ],
              ),
              evidenceSummary: const <String, Object?>{
                'status': 'completed',
                'commandCount': 0,
                'screenshotCount': 1,
                'recordingCount': 0,
                'failureCount': 0,
                'keyframeCount': 1,
              },
              runtimeSummary: const CockpitBundleRuntimeSummary(
                totalEntryCount: 1,
                errorCount: 0,
                warningCount: 1,
                truncated: false,
              ),
            ),
          );
        },
      );

      final result = await tool.call(<String, Object?>{
        'runTask': <String, Object?>{
          'launch': <String, Object?>{
            'projectDir': '/workspace/examples/cockpit_demo',
            'target': 'lib/main.dart',
            'platform': 'android',
            'deviceId': 'emulator-5554',
            'sessionPort': 47331,
          },
          'script': <String, Object?>{
            'sessionId': 'mcp-validate-task-session',
            'taskId': 'mcp-validate-task-id',
            'platform': 'android',
            'commands': <Map<String, Object?>>[_noopCommandJson()],
            'failFast': true,
          },
          'outputRoot': '/tmp/out',
        },
        'validation': const <String, Object?>{
          'expectedClassification': 'completed',
          'requireAcceptanceMarkdown': true,
          'requireArtifactFiles': true,
        },
      });

      expect(
        capturedRequest?.validation.expectedClassification,
        CockpitRunTaskClassification.completed,
      );
      expect(capturedRequest?.validation.requireArtifactFiles, isTrue);
      final structuredContent =
          result['structuredContent'] as Map<String, Object?>;
      expect(structuredContent['classification'], 'completed');
      expect(structuredContent['recommendedNextStep'], 'delivery_ready');
      expect(structuredContent['warnings'], <String>[
        'Automation cleanup failed after task orchestration: stop timeout.',
      ]);
      final bundleSummary =
          structuredContent['bundleSummary'] as Map<String, Object?>;
      expect(bundleSummary['bundleDir'], '/tmp/out/validate-task');
      expect(
        (bundleSummary['runtimeSummary']
            as Map<String, Object?>)['warningCount'],
        1,
      );
      expect(
        (bundleSummary['evidence']
            as Map<String, Object?>)['deliveryKeyframesReady'],
        isTrue,
      );
    },
  );

  test('validate_task tool maps service errors into MCP errors', () async {
    final tool = CockpitValidateTaskTool(
      validateTask: (_) async =>
          throw const FormatException('Invalid validation config.'),
    );

    expect(
      () => tool.call(<String, Object?>{
        'runTask': <String, Object?>{
          'script': <String, Object?>{
            'sessionId': 'mcp-validate-task-session',
            'taskId': 'mcp-validate-task-id',
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
        },
      }),
      throwsA(isA<CockpitMcpError>()),
    );
  });

  test('validate_task tool rejects legacy snake case request fields', () async {
    final tool = CockpitValidateTaskTool(
      validateTask: (_) async => throw UnimplementedError(),
    );

    expect(
      () => tool.call(<String, Object?>{
        'run_task': <String, Object?>{
          'script': <String, Object?>{
            'sessionId': 'mcp-validate-task-session',
            'taskId': 'mcp-validate-task-id',
            'platform': 'android',
            'commands': <Map<String, Object?>>[_noopCommandJson()],
            'failFast': true,
          },
          'outputRoot': '/tmp/out',
        },
      }),
      throwsA(isA<CockpitMcpError>()),
    );
  });
}

Map<String, Object?> _noopCommandJson() => CockpitCommand(
  commandId: 'assert-noop',
  commandType: CockpitCommandType.assertText,
  parameters: const <String, Object?>{'text': 'Ready'},
).toJson();
