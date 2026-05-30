import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:args/command_runner.dart';
import 'package:flutter_cockpit_devtools/flutter_cockpit_devtools.dart';
import 'package:flutter_cockpit_devtools/src/cli/cockpit_interactive_cli_support.dart';
import 'package:flutter_cockpit_devtools/src/cli/commands/run_command_command.dart';
import 'package:test/test.dart';

void main() {
  test('run-command accepts app-json and minimal profile', () async {
    CockpitRunCommandRequest? capturedRequest;
    final stdoutBuffer = StringBuffer();
    final runner = CommandRunner<int>('flutter_cockpit_devtools', 'test')
      ..addCommand(
        RunCommandCommand(
          stdoutSink: stdoutBuffer,
          runCommand: (request) async {
            capturedRequest = request;
            return CockpitRunCommandResult(
              command: const CockpitInteractiveCommandCore(
                commandId: 'tap-1',
                commandType: 'tap',
                success: true,
                durationMs: 42,
                usedCaptureFallback: false,
              ),
              artifacts: const <CockpitInteractiveArtifactDescriptor>[],
            );
          },
        ),
      );

    final exitCode =
        await runner.run(<String>[
          'run-command',
          '--base-url',
          'http://127.0.0.1:47331',
          '--command-json',
          jsonEncode(<String, Object?>{
            'commandId': 'tap-1',
            'commandType': 'tap',
          }),
          '--profile',
          'minimal',
          '--stdout-format',
          'json',
        ]) ??
        0;

    expect(exitCode, 0);
    expect(capturedRequest?.command.commandId, 'tap-1');
    expect(capturedRequest?.resultProfile.name.jsonValue, 'minimal');
    final decoded = jsonDecode(stdoutBuffer.toString()) as Map<String, Object?>;
    expect(decoded['command'], isA<Map<String, Object?>>());
    expect(stdoutBuffer.toString(), isNot(contains('\n  "')));
  });

  test(
    'run-command writes pretty json files when output-format json is used',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'cockpit_run_command',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });
      final outputFile = File(p.join(tempDir.path, 'result.json'));
      final stdoutBuffer = StringBuffer();
      final runner = CommandRunner<int>('flutter_cockpit_devtools', 'test')
        ..addCommand(
          RunCommandCommand(
            stdoutSink: stdoutBuffer,
            runCommand: (_) async => CockpitRunCommandResult(
              command: const CockpitInteractiveCommandCore(
                commandId: 'tap-1',
                commandType: 'tap',
                success: true,
                durationMs: 42,
                usedCaptureFallback: false,
              ),
              artifacts: const <CockpitInteractiveArtifactDescriptor>[],
            ),
          ),
        );

      final exitCode =
          await runner.run(<String>[
            'run-command',
            '--base-url',
            'http://127.0.0.1:47331',
            '--command-json',
            jsonEncode(<String, Object?>{
              'commandId': 'tap-1',
              'commandType': 'tap',
            }),
            '--output',
            outputFile.path,
            '--output-format',
            'json',
          ]) ??
          0;

      expect(exitCode, 0);
      expect(stdoutBuffer.toString().trim(), 'output=${outputFile.path}');
      final written = await outputFile.readAsString();
      expect(written, contains('\n  "command"'));
      final decoded = jsonDecode(written) as Map<String, Object?>;
      expect(decoded['command'], isA<Map<String, Object?>>());
    },
  );

  test('AI renderer prioritizes compact issue evidence', () {
    final rendered = cockpitRenderAiPayload(
      commandName: 'read-task-bundle-summary',
      payload: <String, Object?>{
        'status': 'failed',
        'issueEvidence': <String, Object?>{
          'schemaVersion': 1,
          'status': 'failed',
          'failureSummary': 'Expected route /editor was not reached.',
          'recommendedNextStep': 'inspect_issue_evidence',
          'issueKinds': <String>[
            'commandFailure',
            'runtimeError',
            'artifactIssue',
            'gateFailure',
          ],
          'failedCommands': <Object?>[
            <String, Object?>{
              'commandId': 'open-editor',
              'commandType': 'tap',
              'errorCode': 'timeout',
              'routeName': '/inbox',
              'expectedRouteName': '/editor',
              'diagnosticsArtifactPath':
                  '/tmp/bundle/diagnostics/step_000_open_editor.json',
            },
          ],
          'runtimeIssues': <Object?>[
            <String, Object?>{
              'kind': 'flutterError',
              'severity': 'error',
              'message': 'Navigator push failed',
            },
          ],
          'artifactIssues': <Object?>[
            <String, Object?>{
              'code': 'diagnosticsArtifactUnreadable',
              'path': '/tmp/bundle/diagnostics/step_000_open_editor.json',
            },
          ],
          'gateFailures': <Object?>[
            <String, Object?>{
              'gate': 'finalAssertionPassed',
              'failureCodes': <String>['runtimeErrorsDetected'],
            },
          ],
          'evidencePaths': <String, Object?>{
            'primaryScreenshotPath': '/tmp/bundle/screenshots/after_tap.png',
            'diagnosticsArtifactPaths': <String>[
              '/tmp/bundle/diagnostics/step_000_open_editor.json',
            ],
          },
        },
      },
    );

    expect(rendered, contains('issues'));
    expect(rendered, contains('issueEvidence status=failed'));
    expect(rendered, contains('failedCommand[0] commandId=open-editor'));
    expect(rendered, contains('runtimeIssue[0] kind=flutterError'));
    expect(
      rendered,
      contains('artifactIssue[0] code=diagnosticsArtifactUnreadable'),
    );
    expect(rendered, contains('gateFailure[0] gate=finalAssertionPassed'));
    expect(rendered, contains('evidencePaths screenshot='));
    expect(rendered, isNot(contains('\n  issueEvidence={')));
  });

  test('AI renderer promotes nested bundle issue evidence', () {
    final rendered = cockpitRenderAiPayload(
      commandName: 'run-task',
      payload: <String, Object?>{
        'classification': 'failed',
        'recommendedNextStep': 'inspect_issue_evidence',
        'bundleSummary': <String, Object?>{
          'bundleDir': '/tmp/bundle',
          'issueEvidence': <String, Object?>{
            'schemaVersion': 1,
            'status': 'failed',
            'recommendedNextStep': 'inspect_issue_evidence',
            'issueKinds': <String>['commandFailure'],
            'failedCommands': <Object?>[
              <String, Object?>{
                'commandId': 'save-form',
                'commandType': 'tap',
                'errorCode': 'timeout',
              },
            ],
          },
        },
      },
    );

    expect(rendered, contains('issues'));
    expect(rendered, contains('issueEvidence status=failed'));
    expect(rendered, contains('failedCommand[0] commandId=save-form'));
    expect(rendered, isNot(contains('bundleSummary=')));
    expect(rendered, isNot(contains('issueEvidence={')));
  });

  test('AI renderer preserves compact bundle summary context', () {
    final rendered = cockpitRenderAiPayload(
      commandName: 'run-task',
      payload: <String, Object?>{
        'classification': 'completed',
        'recommendedNextStep': 'delivery_ready',
        'bundleSummary': <String, Object?>{
          'bundleDir': '/tmp/bundle',
          'manifest': <String, Object?>{
            'sessionId': 'session-1',
            'taskId': 'task-1',
            'platform': 'ios',
            'status': 'completed',
          },
          'evidenceSummary': <String, Object?>{
            'commandCount': 6,
            'screenshotCount': 3,
            'recordingCount': 1,
            'failureCount': 0,
          },
          'artifactPaths': <String, Object?>{
            'primaryScreenshotPath': '/tmp/bundle/screenshots/acceptance.png',
            'primaryRecordingPath': '/tmp/bundle/recordings/acceptance.mp4',
          },
        },
      },
    );

    expect(rendered, contains('bundle dir=/tmp/bundle'));
    expect(rendered, contains('sessionId=session-1'));
    expect(rendered, contains('platform=ios'));
    expect(rendered, contains('commands=6'));
    expect(rendered, contains('screenshots=3'));
    expect(rendered, contains('recordings=1'));
    expect(rendered, contains('primaryScreenshot='));
    expect(rendered, contains('primaryRecording='));
    expect(rendered, isNot(contains('bundleSummary=')));
  });

  test('run-command reports invalid command json as a usage error', () async {
    final runner = CommandRunner<int>('flutter_cockpit_devtools', 'test')
      ..addCommand(RunCommandCommand());

    await expectLater(
      () => runner.run(<String>[
        'run-command',
        '--base-url',
        'http://127.0.0.1:47331',
        '--command-json',
        jsonEncode(<String, Object?>{
          'commandId': 'capture-1',
          'commandType': 'captureScreenshot',
          'screenshotRequest': <String, Object?>{
            'reason': 'debug',
            'name': 'invalid-reason',
          },
        }),
      ]),
      throwsA(
        isA<UsageException>().having(
          (error) => error.message,
          'message',
          contains('command JSON is invalid'),
        ),
      ),
    );
  });
}
