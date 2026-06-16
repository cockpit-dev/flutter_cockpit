import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:cockpit/src/application/cockpit_bundle_artifact_paths.dart';
import 'package:cockpit/src/application/cockpit_read_task_bundle_summary_service.dart';
import 'package:cockpit/src/application/cockpit_run_task_service.dart';
import 'package:cockpit/src/application/cockpit_validate_task_service.dart';
import 'package:cockpit/src/cli/commands/validate_task_command.dart';
import 'package:cockpit/src/runner/cockpit_workflow_step.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test(
    'validate-task reads config json and emits a structured validation result payload',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'cockpit_validate_task_cli',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      final configFile = File(p.join(tempDir.path, 'validate_task.json'));
      await configFile.writeAsString(
        jsonEncode(<String, Object?>{
          'runTask': <String, Object?>{
            'launch': <String, Object?>{
              'projectDir': '/workspace/examples/cockpit_demo',
              'target': 'lib/main.dart',
              'platform': 'android',
              'deviceId': 'emulator-5554',
              'sessionPort': 47331,
            },
            'script': <String, Object?>{
              'sessionId': 'cli-validate-task-session',
              'taskId': 'cli-validate-task-id',
              'platform': 'android',
              'commands': <Map<String, Object?>>[_noopCommandJson()],
              'failFast': true,
            },
            'outputRoot': tempDir.path,
          },
          'validation': const <String, Object?>{
            'expectedClassification': 'completed',
            'requireAcceptanceMarkdown': true,
            'requireEnvironmentSnapshot': true,
            'requirePrimaryScreenshot': true,
            'requireArtifactFiles': true,
          },
        }),
      );

      final outputFile = File(p.join(tempDir.path, 'result.json'));
      CockpitValidateTaskRequest? capturedRequest;
      final runner =
          CommandRunner<int>(
            'cockpit',
            'Host-side tooling for flutter_cockpit.',
          )..addCommand(
            ValidateTaskCommand(
              service: CockpitValidateTaskService(
                validateTask: (request) async {
                  capturedRequest = request;
                  return CockpitValidateTaskResult(
                    classification: CockpitValidationClassification.completed,
                    recommendedNextStep: 'delivery_ready',
                    runTaskResult: CockpitRunTaskResult(
                      classification: CockpitRunTaskClassification.completed,
                      recommendedNextStep: 'delivery_ready',
                    ),
                    bundleSummary: CockpitReadTaskBundleSummaryResult(
                      bundleDir: tempDir.path,
                      manifest: CockpitRunManifest(
                        sessionId: 'cli-validate-task-session',
                        taskId: 'cli-validate-task-id',
                        platform: 'android',
                        status: CockpitTaskStatus.completed,
                        startedAt: DateTime.utc(2026, 3, 21, 0, 0),
                        finishedAt: DateTime.utc(2026, 3, 21, 0, 5),
                        deliveryArtifactsReady: true,
                      ),
                      handoff: const <String, Object?>{'status': 'completed'},
                      delivery: const <String, Object?>{
                        'primaryScreenshotRef': 'screenshots/acceptance.png',
                      },
                      acceptanceMarkdown: '# Acceptance',
                      artifactPaths: CockpitBundleArtifactPaths(
                        primaryScreenshotPath: p.join(
                          tempDir.path,
                          'screenshots',
                          'acceptance.png',
                        ),
                      ),
                      evidenceSummary: const <String, Object?>{
                        'status': 'completed',
                        'commandCount': 0,
                        'screenshotCount': 1,
                        'recordingCount': 0,
                        'failureCount': 0,
                      },
                    ),
                  );
                },
              ),
            ),
          );

      final exitCode =
          await runner.run(<String>[
            'validate-task',
            '--config-json',
            configFile.path,
            '--output',
            outputFile.path,
            '--output-format',
            'json',
          ]) ??
          0;

      expect(exitCode, 0);
      expect(
        capturedRequest?.validation.expectedClassification,
        CockpitRunTaskClassification.completed,
      );
      expect(capturedRequest?.validation.requireArtifactFiles, isTrue);
      expect(capturedRequest?.runTask.launch?.platform, 'android');

      final decoded =
          jsonDecode(await outputFile.readAsString()) as Map<String, Object?>;
      expect(decoded['classification'], 'completed');
      expect(decoded['recommendedNextStep'], 'delivery_ready');
      expect(
        (decoded['bundleSummary'] as Map<String, Object?>)['bundleDir'],
        tempDir.path,
      );
    },
  );

  test('validate-task reads YAML config through --config', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'cockpit_validate_task_yaml_cli',
    );
    addTearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    final configFile = File(p.join(tempDir.path, 'validate_task.yaml'));
    await configFile.writeAsString('''
runTask:
  launch:
    projectDir: /workspace/examples/cockpit_demo
    target: lib/main.dart
    platform: android
    deviceId: emulator-5554
    sessionPort: 47331
  script:
    schemaVersion: 1
    sessionId: cli-validate-task-yaml-session
    taskId: cli-validate-task-yaml-id
    platform: android
    failFast: true
    steps:
      - stepId: wait-ready
        stepType: retry
        maxAttempts: 2
        delayMs: 0
        step:
          stepType: command
          command:
            commandId: assert-ready
            commandType: assertText
            parameters:
              text: Ready
  outputRoot: ${tempDir.path}
validation:
  expectedClassification: completed
  requireAcceptanceMarkdown: true
  requireArtifactFiles: false
''');

    CockpitValidateTaskRequest? capturedRequest;
    final runner =
        CommandRunner<int>('cockpit', 'Host-side tooling for flutter_cockpit.')
          ..addCommand(
            ValidateTaskCommand(
              service: CockpitValidateTaskService(
                validateTask: (request) async {
                  capturedRequest = request;
                  return CockpitValidateTaskResult(
                    classification: CockpitValidationClassification.completed,
                    recommendedNextStep: 'delivery_ready',
                    runTaskResult: CockpitRunTaskResult(
                      classification: CockpitRunTaskClassification.completed,
                      recommendedNextStep: 'delivery_ready',
                    ),
                  );
                },
              ),
            ),
          );

    final exitCode =
        await runner.run(<String>[
          'validate-task',
          '--config',
          configFile.path,
        ]) ??
        0;

    expect(exitCode, 0);
    expect(capturedRequest?.runTask.launch?.deviceId, 'emulator-5554');
    expect(capturedRequest?.runTask.script.commands, isEmpty);
    expect(capturedRequest?.runTask.script.workflowSteps, hasLength(1));
    expect(
      capturedRequest?.runTask.script.workflowSteps.single,
      isA<CockpitRetryWorkflowStep>(),
    );
    expect(capturedRequest?.validation.requireAcceptanceMarkdown, isTrue);
  });
}

Map<String, Object?> _noopCommandJson() => CockpitCommand(
  commandId: 'assert-noop',
  commandType: CockpitCommandType.assertText,
  parameters: const <String, Object?>{'text': 'Ready'},
).toJson();
