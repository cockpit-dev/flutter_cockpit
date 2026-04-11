import 'dart:io';

final class CockpitRunShellRequest {
  const CockpitRunShellRequest({
    required this.command,
    this.scope = 'host',
    this.workingDirectory,
  });

  final List<String> command;
  final String scope;
  final String? workingDirectory;
}

final class CockpitRunShellResult {
  const CockpitRunShellResult({
    required this.scope,
    required this.command,
    required this.exitCode,
    required this.stdout,
    required this.stderr,
    required this.success,
    required this.recommendedNextStep,
  });

  final String scope;
  final List<String> command;
  final int exitCode;
  final String stdout;
  final String stderr;
  final bool success;
  final String recommendedNextStep;

  Map<String, Object?> toJson() => <String, Object?>{
        'scope': scope,
        'command': command,
        'exitCode': exitCode,
        'stdout': stdout,
        'stderr': stderr,
        'success': success,
        'recommendedNextStep': recommendedNextStep,
      };
}

typedef CockpitShellProcessRunner = Future<ProcessResult> Function(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
});

typedef CockpitRunShellFunction = Future<CockpitRunShellResult> Function(
  CockpitRunShellRequest request,
);

final class CockpitRunShellService {
  CockpitRunShellService({
    CockpitRunShellFunction? runShell,
    CockpitShellProcessRunner processRunner = Process.run,
  })  : _runShellOverride = runShell,
        _processRunner = processRunner;

  final CockpitRunShellFunction? _runShellOverride;
  final CockpitShellProcessRunner _processRunner;

  Future<CockpitRunShellResult> run(CockpitRunShellRequest request) async {
    final override = _runShellOverride;
    if (override != null) {
      return override(request);
    }

    if (request.scope != 'host') {
      throw UnsupportedError(
        'run-shell currently supports host scope only.',
      );
    }
    if (request.command.isEmpty) {
      throw ArgumentError.value(
        request.command,
        'command',
        'run-shell requires a non-empty command.',
      );
    }

    final result = await _processRunner(
      request.command.first,
      request.command.skip(1).toList(growable: false),
      workingDirectory: request.workingDirectory,
    );
    final stdoutText = '${result.stdout}'.trimRight();
    final stderrText = '${result.stderr}'.trimRight();
    final success = result.exitCode == 0;
    return CockpitRunShellResult(
      scope: request.scope,
      command: request.command,
      exitCode: result.exitCode,
      stdout: stdoutText,
      stderr: stderrText,
      success: success,
      recommendedNextStep: success ? 'continue' : 'inspectShellFailure',
    );
  }
}
