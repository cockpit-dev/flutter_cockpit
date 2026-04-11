import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';

import '../../application/cockpit_run_shell_service.dart';
import '../cockpit_cli_help.dart';
import '../cockpit_command_runner.dart';
import '../cockpit_interactive_cli_support.dart';

typedef CockpitRunShellCliFunction = Future<CockpitRunShellResult> Function(
  CockpitRunShellRequest request,
);

final class RunShellCommand extends CockpitCliCommand {
  RunShellCommand({
    CockpitRunShellService? service,
    CockpitRunShellCliFunction? runShell,
    StringSink? stdoutSink,
  })  : _runShell = runShell ?? (service ?? CockpitRunShellService()).run,
        _stdoutSink = stdoutSink ?? stdout {
    argParser
      ..addOption(
        'scope',
        allowed: const <String>[
          'host',
          'target',
          'android',
          'ios',
          'macos',
          'windows',
          'linux',
          'web',
        ],
        defaultsTo: 'host',
      )
      ..addOption('target-json')
      ..addOption('device-id')
      ..addOption('working-directory')
      ..addOption('executable')
      ..addMultiOption('arg')
      ..addOption('output-json');
  }

  final CockpitRunShellCliFunction _runShell;
  final StringSink _stdoutSink;

  @override
  String get name => 'run-shell';

  @override
  String get description =>
      'Run a shell command against the current shell scope.';

  @override
  String get summary => 'Run host or target-aware shell commands.';

  @override
  String get category => CockpitCliCategory.workspace;

  @override
  Future<int> run() async {
    final executable = argResults?['executable'] as String?;
    if (executable == null || executable.isEmpty) {
      throw UsageException('--executable is required.', usage);
    }
    final scope = argResults?['scope'] as String? ?? 'host';
    final targetJsonPath = argResults?['target-json'] as String?;
    if (scope == 'target' &&
        (targetJsonPath == null || targetJsonPath.isEmpty)) {
      throw UsageException(
          '--target-json is required for target scope.', usage);
    }
    final args = (argResults?['arg'] as List<String>? ?? const <String>[]);
    final result = await _runShell(
      CockpitRunShellRequest(
        scope: scope,
        command: <String>[executable, ...args],
        targetHandlePath: targetJsonPath,
        deviceId: argResults?['device-id'] as String?,
        workingDirectory: argResults?['working-directory'] as String?,
      ),
    );
    await cockpitWriteJsonPayload(
      payload: const JsonEncoder.withIndent('  ').convert(result.toJson()),
      argResults: argResults,
      stdoutSink: _stdoutSink,
    );
    return cockpitSuccessExitCode;
  }
}
