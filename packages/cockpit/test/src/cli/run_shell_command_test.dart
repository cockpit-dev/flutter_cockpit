import 'dart:convert';

import 'package:args/command_runner.dart';
import 'package:cockpit/src/application/cockpit_run_shell_service.dart';
import 'package:cockpit/src/cli/commands/run_shell_command.dart';
import 'package:test/test.dart';

void main() {
  test('run-shell executes a host command through the cli surface', () async {
    final output = StringBuffer();
    final runner = CommandRunner<int>('cockpit', 'test')
      ..addCommand(
        RunShellCommand(
          stdoutSink: output,
          runShell: (_) async => const CockpitRunShellResult(
            scope: 'host',
            command: <String>['dart', '--version'],
            exitCode: 0,
            stdout: 'Dart SDK version: 3.10.8',
            stderr: '',
            success: true,
            recommendedNextStep: 'continue',
          ),
        ),
      );

    final exitCode =
        await runner.run(<String>[
          'run-shell',
          '--stdout-format',
          'json',
          '--executable',
          'dart',
          '--arg=--version',
        ]) ??
        0;

    expect(exitCode, 0);
    final decoded = jsonDecode(output.toString()) as Map<String, Object?>;
    expect(decoded['scope'], 'host');
    expect(decoded['success'], isTrue);
  });

  test(
    'run-shell forwards target-json for target-aware shell execution',
    () async {
      final output = StringBuffer();
      CockpitRunShellRequest? capturedRequest;
      final runner = CommandRunner<int>('cockpit', 'test')
        ..addCommand(
          RunShellCommand(
            stdoutSink: output,
            runShell: (request) async {
              capturedRequest = request;
              return const CockpitRunShellResult(
                scope: 'android',
                command: <String>['getprop', 'ro.build.version.sdk'],
                exitCode: 0,
                stdout: '34',
                stderr: '',
                success: true,
                recommendedNextStep: 'continue',
              );
            },
          ),
        );

      final exitCode =
          await runner.run(<String>[
            'run-shell',
            '--scope',
            'target',
            '--target-json',
            '/tmp/target.json',
            '--executable',
            'getprop',
            '--arg=ro.build.version.sdk',
          ]) ??
          0;

      expect(exitCode, 0);
      expect(capturedRequest?.scope, 'target');
      expect(capturedRequest?.targetHandlePath, '/tmp/target.json');
    },
  );

  test('run-shell forwards the explicit timeout budget', () async {
    final output = StringBuffer();
    CockpitRunShellRequest? capturedRequest;
    final runner = CommandRunner<int>('cockpit', 'test')
      ..addCommand(
        RunShellCommand(
          stdoutSink: output,
          runShell: (request) async {
            capturedRequest = request;
            return const CockpitRunShellResult(
              scope: 'host',
              command: <String>['dart', '--version'],
              exitCode: 0,
              stdout: 'Dart SDK version: 3.10.8',
              stderr: '',
              success: true,
              recommendedNextStep: 'continue',
            );
          },
        ),
      );

    final exitCode =
        await runner.run(<String>[
          'run-shell',
          '--timeout-seconds',
          '7',
          '--executable',
          'dart',
          '--arg=--version',
        ]) ??
        0;

    expect(exitCode, 0);
    expect(capturedRequest?.timeout, const Duration(seconds: 7));
  });
}
