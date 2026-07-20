import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:cockpit_protocol/cockpit_protocol.dart';
import 'package:cockpit/src/application/cockpit_application_service_exception.dart';
import 'package:cockpit/src/application/cockpit_bundle_artifact_paths.dart';
import 'package:cockpit/src/application/cockpit_read_task_bundle_summary_service.dart';
import 'package:cockpit/src/application/cockpit_run_task_service.dart';
import 'package:cockpit/src/cli/commands/run_task_command.dart';
import 'package:cockpit/src/runner/cockpit_workflow_step.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test(
    'run-task reads config json and emits a structured result payload',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'cockpit_run_task_cli',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      final configFile = File(p.join(tempDir.path, 'run_task.json'));
      await configFile.writeAsString(
        jsonEncode(<String, Object?>{
          'launch': <String, Object?>{
            'projectDir': '/workspace/examples/cockpit_demo',
            'target': 'lib/main.dart',
            'platform': 'android',
            'deviceId': 'emulator-5554',
            'sessionPort': 47331,
          },
          'script': <String, Object?>{
            'sessionId': 'cli-run-task-session',
            'taskId': 'cli-run-task-id',
            'platform': 'android',
            'commands': <Map<String, Object?>>[_noopCommandJson()],
            'failFast': true,
          },
          'outputRoot': tempDir.path,
          'baseline': const <String, Object?>{
            'captureScreenshot': true,
            'screenshotName': 'cli-baseline',
            'includeSnapshot': true,
          },
          'requirements': const <String, Object?>{
            'requireScreenshotEvidence': true,
            'requireVideoEvidence': false,
          },
        }),
      );

      final outputFile = File(p.join(tempDir.path, 'result.json'));
      CockpitRunTaskRequest? capturedRequest;
      final runner =
          CommandRunner<int>(
            'cockpit',
            'Host-side tooling for flutter_cockpit.',
          )..addCommand(
            RunTaskCommand(
              service: CockpitRunTaskService(
                runTask: (request) async {
                  capturedRequest = request;
                  return CockpitRunTaskResult(
                    classification: CockpitRunTaskClassification.completed,
                    recommendedNextStep: 'delivery_ready',
                    bundleSummary: CockpitReadTaskBundleSummaryResult(
                      bundleDir: tempDir.path,
                      manifest: CockpitRunManifest(
                        sessionId: 'cli-run-task-session',
                        taskId: 'cli-run-task-id',
                        platform: 'android',
                        status: CockpitTaskStatus.completed,
                        startedAt: DateTime.utc(2026, 3, 21, 0, 0),
                        finishedAt: DateTime.utc(2026, 3, 21, 0, 5),
                      ),
                      handoff: const <String, Object?>{'status': 'completed'},
                      delivery: const <String, Object?>{},
                      acceptanceMarkdown: '# Acceptance',
                      artifactPaths: CockpitBundleArtifactPaths(),
                      evidenceSummary: const <String, Object?>{
                        'status': 'completed',
                        'commandCount': 0,
                        'screenshotCount': 0,
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
            'run-task',
            '--config-json',
            configFile.path,
            '--output',
            outputFile.path,
            '--output-format',
            'json',
          ]) ??
          0;

      expect(exitCode, 0);
      expect(capturedRequest?.launch?.platform, 'android');
      expect(capturedRequest?.baseline.captureScreenshot, isTrue);
      expect(capturedRequest?.script.environment, isNull);

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

  test('run-task reads YAML config through --config', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'cockpit_run_task_yaml_cli',
    );
    addTearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    final configFile = File(p.join(tempDir.path, 'run_task.yaml'));
    await configFile.writeAsString('''
launch:
  projectDir: /workspace/examples/cockpit_demo
  target: lib/main.dart
  flavor: staging
  platform: android
  deviceId: emulator-5554
  sessionPort: 47331
  launchConfiguration:
    dartDefines:
      - API_URL=https://example.test
    dartDefineFromFiles:
      - config/dev.json
    flutterArgs:
      - --track-widget-creation
    environment:
      API_TOKEN: secret
script:
  schemaVersion: 1
  sessionId: cli-run-task-yaml-session
  taskId: cli-run-task-yaml-id
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
baseline:
  captureScreenshot: true
  screenshotName: cli-baseline
requirements:
  requireScreenshotEvidence: false
''');

    CockpitRunTaskRequest? capturedRequest;
    final runner =
        CommandRunner<int>('cockpit', 'Host-side tooling for flutter_cockpit.')
          ..addCommand(
            RunTaskCommand(
              service: CockpitRunTaskService(
                runTask: (request) async {
                  capturedRequest = request;
                  return CockpitRunTaskResult(
                    classification: CockpitRunTaskClassification.completed,
                    recommendedNextStep: 'delivery_ready',
                  );
                },
              ),
            ),
          );

    final exitCode =
        await runner.run(<String>['run-task', '--config', configFile.path]) ??
        0;

    expect(exitCode, 0);
    expect(capturedRequest?.launch?.deviceId, 'emulator-5554');
    expect(capturedRequest?.launch?.flavor, 'staging');
    expect(capturedRequest?.launch?.launchConfiguration.dartDefines, <String>[
      'API_URL=https://example.test',
    ]);
    expect(
      capturedRequest?.launch?.launchConfiguration.dartDefineFromFiles,
      <String>['config/dev.json'],
    );
    expect(capturedRequest?.launch?.launchConfiguration.flutterArgs, <String>[
      '--track-widget-creation',
    ]);
    expect(
      capturedRequest?.launch?.launchConfiguration.environment,
      <String, String>{'API_TOKEN': 'secret'},
    );
    expect(capturedRequest?.baseline.captureScreenshot, isTrue);
    expect(capturedRequest?.script.commands, isEmpty);
    expect(capturedRequest?.script.workflowSteps, hasLength(1));
    expect(
      capturedRequest?.script.workflowSteps.single,
      isA<CockpitRetryWorkflowStep>(),
    );
  });

  test('run-task rejects fractional launch timeout seconds', () {
    expect(
      () => CockpitRunTaskRequest.fromJson(<String, Object?>{
        'launch': <String, Object?>{
          'projectDir': '/workspace/examples/cockpit_demo',
          'platform': 'android',
          'deviceId': 'emulator-5554',
          'sessionPort': 47331,
          'launchTimeoutSeconds': 1.5,
        },
        'script': <String, Object?>{
          'sessionId': 'fractional-timeout-session',
          'taskId': 'fractional-timeout-task',
          'platform': 'android',
          'commands': <Map<String, Object?>>[_noopCommandJson()],
        },
        'outputRoot': '/tmp/out',
      }),
      throwsA(
        isA<CockpitApplicationServiceException>()
            .having((error) => error.code, 'code', 'invalidRunTaskRequest')
            .having(
              (error) => error.details['field'],
              'field',
              'launchTimeoutSeconds',
            ),
      ),
    );
  });

  test('run-task rejects non-positive session ports', () {
    expect(
      () => CockpitRunTaskRequest.fromJson(<String, Object?>{
        'launch': <String, Object?>{
          'projectDir': '/workspace/examples/cockpit_demo',
          'platform': 'android',
          'deviceId': 'emulator-5554',
          'sessionPort': 0,
        },
        'script': <String, Object?>{
          'sessionId': 'bad-port-session',
          'taskId': 'bad-port-task',
          'platform': 'android',
          'commands': <Map<String, Object?>>[_noopCommandJson()],
        },
        'outputRoot': '/tmp/out',
      }),
      throwsA(
        isA<CockpitApplicationServiceException>()
            .having((error) => error.code, 'code', 'invalidRunTaskRequest')
            .having((error) => error.details['field'], 'field', 'sessionPort'),
      ),
    );
  });

  test('run-task rejects invalid launch configuration with field details', () {
    expect(
      () => CockpitRunTaskRequest.fromJson(<String, Object?>{
        'launch': <String, Object?>{
          'projectDir': '/workspace/examples/cockpit_demo',
          'platform': 'android',
          'deviceId': 'emulator-5554',
          'sessionPort': 47331,
          'launchConfiguration': <String, Object?>{
            'flutterArgs': <String>['--dart-define API_URL=https://example'],
          },
        },
        'script': <String, Object?>{
          'sessionId': 'invalid-launch-config-session',
          'taskId': 'invalid-launch-config-task',
          'platform': 'android',
          'commands': <Map<String, Object?>>[_noopCommandJson()],
        },
        'outputRoot': '/tmp/out',
      }),
      throwsA(
        isA<CockpitApplicationServiceException>()
            .having((error) => error.code, 'code', 'invalidLaunchConfiguration')
            .having((error) => error.details['field'], 'field', 'flutterArgs'),
      ),
    );
  });
}

Map<String, Object?> _noopCommandJson() => CockpitCommand(
  commandId: 'assert-noop',
  commandType: CockpitCommandType.assertText,
  parameters: const <String, Object?>{'text': 'Ready'},
).toJson();
