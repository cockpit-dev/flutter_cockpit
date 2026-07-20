import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:cockpit_protocol/cockpit_protocol.dart';
import 'package:cockpit/src/application/cockpit_bundle_artifact_paths.dart';
import 'package:cockpit/src/application/cockpit_read_task_bundle_summary_service.dart';
import 'package:cockpit/src/cli/commands/read_task_bundle_summary_command.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test(
    'read-task-bundle-summary reads a bundle and defaults to AI output',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'cockpit_read_bundle_summary_cli',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      CockpitReadTaskBundleSummaryRequest? capturedRequest;
      final stdoutBuffer = StringBuffer();
      final runner =
          CommandRunner<int>(
            'cockpit',
            'Host-side tooling for flutter_cockpit.',
          )..addCommand(
            ReadTaskBundleSummaryCommand(
              stdoutSink: stdoutBuffer,
              readSummary: (request) async {
                capturedRequest = request;
                return _summaryResult(bundleDir: request.bundleDir);
              },
            ),
          );

      final exitCode =
          await runner.run(<String>[
            'read-task-bundle-summary',
            '--bundle-dir',
            tempDir.path,
          ]) ??
          0;

      expect(exitCode, 0);
      expect(capturedRequest?.bundleDir, tempDir.path);
      final text = stdoutBuffer.toString();
      expect(text, contains('cockpit.v=1'));
      expect(text, contains('command=read-task-bundle-summary'));
      expect(text, contains('command=read-task-bundle-summary\nstatus=failed'));
      expect(text, contains('issueEvidence status=failed'));
      expect(text, contains('failedCommand[0] commandId=open-editor'));
      expect(text, contains('bundle'));
      expect(text, contains('bundle dir=${tempDir.path}'));
      expect(text, contains('sessionId=session-1'));
      expect(text, contains('taskId=task-1'));
      expect(text, contains('counts commands=2 failures=1 screenshots=1'));
      expect(text, isNot(contains('manifest={')));
      expect(text, isNot(contains('evidenceSummary={')));
      expect(() => jsonDecode(text), throwsA(isA<FormatException>()));
    },
  );

  test('read-task-bundle-summary supports compact JSON stdout', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'cockpit_read_bundle_summary_json_cli',
    );
    addTearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    final stdoutBuffer = StringBuffer();
    final runner =
        CommandRunner<int>('cockpit', 'Host-side tooling for flutter_cockpit.')
          ..addCommand(
            ReadTaskBundleSummaryCommand(
              stdoutSink: stdoutBuffer,
              readSummary: (request) async =>
                  _summaryResult(bundleDir: request.bundleDir),
            ),
          );

    final exitCode =
        await runner.run(<String>[
          'read-task-bundle-summary',
          '--bundle-dir',
          tempDir.path,
          '--stdout-format',
          'json',
        ]) ??
        0;

    expect(exitCode, 0);
    final decoded = jsonDecode(stdoutBuffer.toString()) as Map<String, Object?>;
    expect(decoded['bundleDir'], tempDir.path);
    expect(decoded['manifest'], isA<Map<String, Object?>>());
    expect(decoded['issueEvidence'], isA<Map<String, Object?>>());
    expect(stdoutBuffer.toString(), isNot(contains('\n  "')));
  });

  test(
    'read-task-bundle-summary writes file output as paths-only stdout',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'cockpit_read_bundle_summary_file_cli',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      final outputFile = File(p.join(tempDir.path, 'summary.json'));
      final stdoutBuffer = StringBuffer();
      final runner =
          CommandRunner<int>(
            'cockpit',
            'Host-side tooling for flutter_cockpit.',
          )..addCommand(
            ReadTaskBundleSummaryCommand(
              stdoutSink: stdoutBuffer,
              readSummary: (request) async =>
                  _summaryResult(bundleDir: request.bundleDir),
            ),
          );

      final exitCode =
          await runner.run(<String>[
            'read-task-bundle-summary',
            '--bundle-dir',
            tempDir.path,
            '--output',
            outputFile.path,
            '--output-format',
            'json',
          ]) ??
          0;

      expect(exitCode, 0);
      expect(stdoutBuffer.toString().trim(), 'output=${outputFile.path}');
      final decoded = jsonDecode(await outputFile.readAsString());
      expect(decoded, isA<Map<String, Object?>>());
    },
  );
}

CockpitReadTaskBundleSummaryResult _summaryResult({required String bundleDir}) {
  return CockpitReadTaskBundleSummaryResult(
    bundleDir: bundleDir,
    manifest: CockpitRunManifest(
      sessionId: 'session-1',
      taskId: 'task-1',
      platform: 'macos',
      status: CockpitTaskStatus.failed,
      startedAt: DateTime.utc(2026, 5, 30, 0, 0),
      finishedAt: DateTime.utc(2026, 5, 30, 0, 1),
      failureSummary: 'Expected route /editor was not reached.',
      commandCount: 2,
      screenshotCount: 1,
      failureCount: 1,
    ),
    handoff: const <String, Object?>{'status': 'failed'},
    delivery: const <String, Object?>{
      'primaryScreenshotRef': 'screenshots/after_tap.png',
    },
    acceptanceMarkdown: '# Acceptance',
    artifactPaths: CockpitBundleArtifactPaths(
      primaryScreenshotPath: p.join(bundleDir, 'screenshots', 'after_tap.png'),
    ),
    evidenceSummary: const <String, Object?>{
      'status': 'failed',
      'commandCount': 2,
      'screenshotCount': 1,
      'recordingCount': 0,
      'failureCount': 1,
    },
    issueEvidence: const <String, Object?>{
      'status': 'failed',
      'recommendedNextStep': 'inspect_issue_evidence',
      'failedCommands': <Object?>[
        <String, Object?>{
          'commandId': 'open-editor',
          'commandType': 'tap',
          'errorCode': 'timeout',
        },
      ],
    },
  );
}
