import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_bundle_artifact_paths.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_read_task_bundle_summary_service.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_run_task_service.dart';
import 'package:flutter_cockpit_devtools/src/cli/commands/run_task_command.dart';
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
            'commands': <Map<String, Object?>>[],
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
            'flutter_cockpit_devtools',
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
}
