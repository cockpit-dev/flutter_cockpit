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
        ],
        defaultsTo: 'host',
        help: 'Host, target handle, or explicit platform shell scope.',
      )
      ..addOption(
        'target-json',
        help: 'Normalized target handle JSON for --scope target.',
      )
      ..addOption(
        'device-id',
        help: 'Explicit device or simulator identifier for platform scopes.',
      )
      ..addOption(
        'working-directory',
        help: 'Host working directory for host-aligned shell execution.',
      )
      ..addOption('executable', help: 'Executable or entry command to run.')
      ..addMultiOption(
        'arg',
        help: 'Repeatable argument passed through to the executable.',
      )
      ..addOption(
        'output-json',
        help: 'Optional path where the shell result JSON should be written.',
      );
  }

  final CockpitRunShellCliFunction _runShell;
  final StringSink _stdoutSink;

  @override
  String get name => 'run-shell';

  @override
  String get description =>
      'Run a shell command against a host or target-aware shell scope.';

  @override
  String get summary => 'Run host or target-aware shell commands.';

  @override
  String get category => CockpitCliCategory.workspace;

  @override
  String get helpWhen =>
      'Use when the next fact lives in host, target, or platform shell state rather than Flutter semantics or bundle output.';

  @override
  String get helpNeeds =>
      'An executable plus either a host scope, an explicit platform scope, or --target-json when --scope target is used.';

  @override
  String get helpShape =>
      'Pass one --executable plus repeated --arg values. Use --scope target with --target-json for normalized target shells, or platform scopes such as android and ios when the device is already known. Browser targets do not expose a direct shell scope.';

  @override
  String get helpExample =>
      'flutter_cockpit_devtools run-shell --scope target --target-json /tmp/target.json --executable getprop --arg ro.build.version.sdk';

  @override
  String get helpWrites =>
      'Structured shell result JSON with scope, command, exitCode, stdout, stderr, and success.';

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
