import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_bundle_artifact_paths.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_read_task_bundle_summary_service.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_run_task_service.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_validate_task_service.dart';
import 'package:flutter_cockpit_devtools/src/cli/commands/validate_task_command.dart';
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
              'commands': <Map<String, Object?>>[],
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
      final runner = CommandRunner<int>(
        'flutter_cockpit_devtools',
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

      final exitCode = await runner.run(<String>[
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
}
