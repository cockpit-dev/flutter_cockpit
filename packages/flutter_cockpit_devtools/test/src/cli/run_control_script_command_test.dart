import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:flutter_cockpit_devtools/flutter_cockpit_devtools.dart';
import 'package:flutter_cockpit_devtools/src/cli/commands/run_control_script_command.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test('run-control-script executes commands and writes a bundle', () async {
    final tempDir = await Directory.systemTemp.createTemp('cockpit_script_cli');
    addTearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    final scriptFile = File(p.join(tempDir.path, 'control_script.json'));
    await scriptFile.writeAsString(
      jsonEncode(<String, Object?>{
        'sessionId': 'cli-session',
        'taskId': 'cli-task',
        'platform': 'android',
        'environment': const CockpitEnvironment(
          platform: 'android',
          flutterVersion: '3.38.9',
          dartVersion: '3.10.8',
        ).toJson(),
        'commands': <Map<String, Object?>>[
          CockpitCommand(
            commandId: 'cmd-open',
            commandType: CockpitCommandType.tap,
            locator: const CockpitLocator(
              kind: CockpitLocatorKind.cockpitId,
              value: 'open_form_button',
            ),
          ).toJson(),
          CockpitCommand(
            commandId: 'cmd-capture',
            commandType: CockpitCommandType.captureScreenshot,
            screenshotRequest: const CockpitScreenshotRequest(
              reason: CockpitScreenshotReason.acceptance,
              name: 'home',
              includeSnapshot: true,
              attachToStep: true,
            ),
          ).toJson(),
        ],
      }),
    );

    final runner = CommandRunner<int>('flutter_cockpit_devtools', 'test')
      ..addCommand(
        RunControlScriptCommand(
          automationAdapter: _FakeAutomationAdapter(
            capabilities: CockpitCapabilities(
              platform: 'android',
              transportType: 'inApp',
              supportsInAppControl: true,
              supportsFlutterViewCapture: true,
              supportsNativeScreenCapture: false,
              supportsHostAutomation: false,
              supportedCommands: const [
                CockpitCommandType.tap,
                CockpitCommandType.captureScreenshot,
              ],
              supportedLocatorStrategies: const [CockpitLocatorKind.cockpitId],
            ),
            resultsByCommandId: <String, CockpitCommandResult>{
              'cmd-open': CockpitCommandResult(
                success: true,
                commandId: 'cmd-open',
                commandType: CockpitCommandType.tap,
                durationMs: 12,
                locatorResolution: const CockpitLocatorResolution(
                  matchedKind: CockpitLocatorKind.cockpitId,
                  matchedValue: 'open_form_button',
                ),
              ),
            },
          ),
          captureAdapter: _FakeCaptureAdapter(
            executionByCommandId: <String, CockpitCommandExecution>{
              'cmd-capture': CockpitCommandExecution(
                result: CockpitCommandResult(
                  success: true,
                  commandId: 'cmd-capture',
                  commandType: CockpitCommandType.captureScreenshot,
                  durationMs: 10,
                  artifacts: const [
                    CockpitArtifactRef(
                      role: 'screenshot',
                      relativePath: 'screenshots/home_acceptance.png',
                    ),
                  ],
                ),
                artifactPayloads: const <String, List<int>>{
                  'screenshots/home_acceptance.png': <int>[7, 8, 9],
                },
              ),
            },
          ),
        ),
      );

    final exitCode = await runner.run([
      'run-control-script',
      '--script-json',
      scriptFile.path,
      '--output-root',
      tempDir.path,
    ]);

    final outputDirectories = tempDir
        .listSync()
        .whereType<Directory>()
        .where(
          (directory) =>
              File(p.join(directory.path, 'manifest.json')).existsSync(),
        )
        .toList(growable: false);

    expect(exitCode, 0);
    expect(outputDirectories, hasLength(1));
    expect(
      File(
        p.join(
          outputDirectories.single.path,
          'screenshots',
          'home_acceptance.png',
        ),
      ).readAsBytesSync(),
      <int>[7, 8, 9],
    );
    final stepsJson = jsonDecode(
      await File(
        p.join(outputDirectories.single.path, 'steps.json'),
      ).readAsString(),
    ) as List<Object?>;
    final manifestJson = jsonDecode(
      await File(
        p.join(outputDirectories.single.path, 'manifest.json'),
      ).readAsString(),
    ) as Map<String, Object?>;

    expect(stepsJson, hasLength(2));
    expect(manifestJson['commandCount'], 2);
    expect(manifestJson['screenshotCount'], 1);
  });

  test(
    'run-control-script returns non-zero when the script file is missing',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'cockpit_script_cli',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      final runner = CommandRunner<int>('flutter_cockpit_devtools', 'test')
        ..addCommand(
          RunControlScriptCommand(
            automationAdapter: _FakeAutomationAdapter(
              capabilities: CockpitCapabilities(
                platform: 'android',
                transportType: 'inApp',
                supportsInAppControl: true,
                supportsFlutterViewCapture: false,
                supportsNativeScreenCapture: false,
                supportsHostAutomation: false,
                supportedCommands: const [CockpitCommandType.tap],
                supportedLocatorStrategies: const [
                  CockpitLocatorKind.cockpitId,
                ],
              ),
              resultsByCommandId: const <String, CockpitCommandResult>{},
            ),
          ),
        );

      final exitCode = await _runCommandRunner(runner, [
        'run-control-script',
        '--script-json',
        p.join(tempDir.path, 'missing.json'),
        '--output-root',
        tempDir.path,
      ]);

      expect(exitCode, isNonZero);
      expect(tempDir.listSync(), isEmpty);
    },
  );

  test(
    'run-control-script returns non-zero when the script omits environment',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'cockpit_script_cli',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      final scriptFile = File(p.join(tempDir.path, 'control_script.json'));
      await scriptFile.writeAsString(
        jsonEncode(<String, Object?>{
          'sessionId': 'cli-session',
          'taskId': 'cli-task',
          'platform': 'android',
          'commands': <Map<String, Object?>>[
            CockpitCommand(
              commandId: 'cmd-open',
              commandType: CockpitCommandType.tap,
              locator: const CockpitLocator(
                kind: CockpitLocatorKind.cockpitId,
                value: 'open_form_button',
              ),
            ).toJson(),
          ],
        }),
      );

      final runner = CommandRunner<int>('flutter_cockpit_devtools', 'test')
        ..addCommand(
          RunControlScriptCommand(
            automationAdapter: _FakeAutomationAdapter(
              capabilities: CockpitCapabilities(
                platform: 'android',
                transportType: 'inApp',
                supportsInAppControl: true,
                supportsFlutterViewCapture: false,
                supportsNativeScreenCapture: false,
                supportsHostAutomation: false,
                supportedCommands: const [CockpitCommandType.tap],
                supportedLocatorStrategies: const [
                  CockpitLocatorKind.cockpitId,
                ],
              ),
              resultsByCommandId: const <String, CockpitCommandResult>{},
            ),
          ),
        );

      final exitCode = await _runCommandRunner(runner, [
        'run-control-script',
        '--script-json',
        scriptFile.path,
        '--output-root',
        tempDir.path,
      ]);

      expect(exitCode, isNonZero);
    },
  );

  test(
    'run-control-script returns non-zero when the written bundle is failed',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'cockpit_script_cli_failed_bundle',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      final scriptFile = File(p.join(tempDir.path, 'control_script.json'));
      await scriptFile.writeAsString(
        jsonEncode(<String, Object?>{
          'sessionId': 'cli-session',
          'taskId': 'cli-task',
          'platform': 'android',
          'environment': const CockpitEnvironment(
            platform: 'android',
            flutterVersion: '3.38.9',
            dartVersion: '3.10.8',
          ).toJson(),
          'commands': <Map<String, Object?>>[
            CockpitCommand(
              commandId: 'cmd-open',
              commandType: CockpitCommandType.tap,
              locator: const CockpitLocator(
                kind: CockpitLocatorKind.cockpitId,
                value: 'open_form_button',
              ),
            ).toJson(),
          ],
        }),
      );

      final runner = CommandRunner<int>('flutter_cockpit_devtools', 'test')
        ..addCommand(
          RunControlScriptCommand(
            automationAdapter: _FakeAutomationAdapter(
              capabilities: CockpitCapabilities(
                platform: 'android',
                transportType: 'inApp',
                supportsInAppControl: true,
                supportsFlutterViewCapture: false,
                supportsNativeScreenCapture: false,
                supportsHostAutomation: false,
                supportedCommands: const [CockpitCommandType.tap],
                supportedLocatorStrategies: const [
                  CockpitLocatorKind.cockpitId,
                ],
              ),
              resultsByCommandId: <String, CockpitCommandResult>{
                'cmd-open': CockpitCommandResult(
                  success: false,
                  commandId: 'cmd-open',
                  commandType: CockpitCommandType.tap,
                  durationMs: 12,
                  error: CockpitCommandError.assertionFailed(
                    message: 'Open button was not visible.',
                  ),
                ),
              },
            ),
          ),
        );

      final exitCode = await _runCommandRunner(runner, [
        'run-control-script',
        '--script-json',
        scriptFile.path,
        '--output-root',
        tempDir.path,
      ]);

      expect(exitCode, isNonZero);
    },
  );
}

Future<int> _runCommandRunner(
  CommandRunner<int> runner,
  List<String> args,
) async {
  try {
    return await runner.run(args) ?? 0;
  } on Object {
    return 1;
  }
}

final class _FakeAutomationAdapter implements CockpitAutomationAdapter {
  _FakeAutomationAdapter({
    required this.capabilities,
    required Map<String, CockpitCommandResult> resultsByCommandId,
  }) : _resultsByCommandId = resultsByCommandId;

  final CockpitCapabilities capabilities;
  final Map<String, CockpitCommandResult> _resultsByCommandId;

  @override
  Future<CockpitCapabilities> describeCapabilities() async => capabilities;

  @override
  Future<CockpitCommandExecution> execute(CockpitCommand command) async {
    return CockpitCommandExecution(
      result: _resultsByCommandId[command.commandId]!,
    );
  }
}

final class _FakeCaptureAdapter implements CockpitCaptureAdapter {
  _FakeCaptureAdapter({
    required Map<String, CockpitCommandExecution> executionByCommandId,
  }) : _executionByCommandId = executionByCommandId;

  final Map<String, CockpitCommandExecution> _executionByCommandId;

  @override
  Future<CockpitCommandExecution> capture(CockpitCommand command) async {
    return _executionByCommandId[command.commandId]!;
  }
}
