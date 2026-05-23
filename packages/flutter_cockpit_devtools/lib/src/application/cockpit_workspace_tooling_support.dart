import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../infrastructure/cockpit_file_system.dart';
import '../infrastructure/cockpit_process_manager.dart';
import '../infrastructure/cockpit_sdk_environment.dart';
import 'cockpit_application_service_exception.dart';
import 'cockpit_workspace_command_result.dart';

enum CockpitWorkspaceToolchain { dart, flutter }

CockpitWorkspaceToolchain detectWorkspaceToolchain(
  CockpitFileSystem fileSystem,
  String workspaceRoot,
) {
  final pubspec = fileSystem.file(p.join(workspaceRoot, 'pubspec.yaml'));
  if (pubspec.existsSync()) {
    final content = pubspec.readAsStringSync();
    if (content.contains('sdk: flutter') || content.contains('\nflutter:')) {
      return CockpitWorkspaceToolchain.flutter;
    }
  }
  return CockpitWorkspaceToolchain.dart;
}

String cockpitPathFromRootUri(String uri) {
  final parsed = Uri.parse(uri);
  if (parsed.scheme != 'file') {
    throw CockpitApplicationServiceException(
      code: 'unsupportedRootUri',
      message: 'Only file:// root URIs are supported.',
      details: <String, Object?>{'uri': uri},
    );
  }
  return p.normalize(parsed.toFilePath());
}

List<String> cockpitPathsFromRootUris(Iterable<String> uris) {
  return List<String>.unmodifiable(uris.map(cockpitPathFromRootUri));
}

String assertWorkspaceRootAllowed(
  String candidatePath,
  List<String> allowedRoots,
) {
  final normalizedCandidate = p.normalize(candidatePath);
  if (allowedRoots.isEmpty) {
    return normalizedCandidate;
  }

  final allowed = allowedRoots.any((root) {
    final normalizedRoot = p.normalize(root);
    return normalizedCandidate == normalizedRoot ||
        p.isWithin(normalizedRoot, normalizedCandidate);
  });
  if (!allowed) {
    throw CockpitApplicationServiceException(
      code: 'workspacePathOutsideRoots',
      message: 'Path is outside the allowed workspace roots.',
      details: <String, Object?>{
        'candidatePath': normalizedCandidate,
        'allowedRoots': allowedRoots,
      },
    );
  }
  return normalizedCandidate;
}

String resolveWorkspaceRoot({
  required String? workspaceRoot,
  required List<String> allowedRoots,
  required String argumentName,
}) {
  if (workspaceRoot case final value? when value.isNotEmpty) {
    return assertWorkspaceRootAllowed(value, allowedRoots);
  }
  if (allowedRoots.length == 1) {
    return p.normalize(allowedRoots.single);
  }
  if (allowedRoots.isEmpty) {
    throw CockpitApplicationServiceException(
      code: 'workspaceRootRequired',
      message:
          'A workspace root is required because no MCP roots are currently configured.',
      details: <String, Object?>{'argument': argumentName},
    );
  }
  throw CockpitApplicationServiceException(
    code: 'workspaceRootAmbiguous',
    message:
        'A workspace root is required because multiple allowed roots are configured.',
    details: <String, Object?>{
      'argument': argumentName,
      'allowedRoots': allowedRoots,
    },
  );
}

Future<CockpitWorkspaceCommandResult> runWorkspaceCommand({
  required CockpitFileSystem fileSystem,
  required CockpitProcessManager processManager,
  required CockpitSdkEnvironment sdkEnvironment,
  required String workspaceRoot,
  List<String> allowedRoots = const <String>[],
  required CockpitWorkspaceToolchain? toolchain,
  required List<String> dartArguments,
  List<String>? flutterArguments,
  Duration? timeout,
}) async {
  final normalizedRoot = assertWorkspaceRootAllowed(
    workspaceRoot,
    allowedRoots,
  );
  final effectiveToolchain =
      toolchain ?? detectWorkspaceToolchain(fileSystem, normalizedRoot);
  final executable = effectiveToolchain == CockpitWorkspaceToolchain.flutter
      ? sdkEnvironment.flutterExecutable
      : sdkEnvironment.dartExecutable;
  final arguments = effectiveToolchain == CockpitWorkspaceToolchain.flutter
      ? (flutterArguments ?? dartArguments)
      : dartArguments;
  return runWorkspaceProcess(
    processManager: processManager,
    executable: executable,
    arguments: arguments,
    workingDirectory: normalizedRoot,
    timeout: timeout,
  );
}

Future<CockpitWorkspaceCommandResult> runWorkspaceProcess({
  required CockpitProcessManager processManager,
  required String executable,
  required List<String> arguments,
  required String workingDirectory,
  Duration? timeout,
}) async {
  final command = CockpitWorkspaceCommand(
    executable: executable,
    arguments: List<String>.unmodifiable(arguments),
    workingDirectory: workingDirectory,
  );
  if (timeout == null) {
    final result = await processManager.run(
      executable,
      arguments,
      workingDirectory: workingDirectory,
    );
    return CockpitWorkspaceCommandResult(
      command: command,
      exitCode: result.exitCode,
      stdout: cockpitProcessOutputText(result.stdout),
      stderr: cockpitProcessOutputText(result.stderr),
    );
  }

  final process = await processManager.start(
    executable,
    arguments,
    workingDirectory: workingDirectory,
  );
  final stdoutFuture = process.stdout.transform(utf8.decoder).join();
  final stderrFuture = process.stderr.transform(utf8.decoder).join();
  try {
    final exitCode = await process.exitCode.timeout(timeout);
    return CockpitWorkspaceCommandResult(
      command: command,
      exitCode: exitCode,
      stdout: await stdoutFuture,
      stderr: await stderrFuture,
    );
  } on TimeoutException {
    if (process.pid != 0) {
      process.kill(ProcessSignal.sigkill);
    }
    final stdout = await stdoutFuture.timeout(
      const Duration(milliseconds: 200),
      onTimeout: () => '',
    );
    final stderr = await stderrFuture.timeout(
      const Duration(milliseconds: 200),
      onTimeout: () => '',
    );
    throw CockpitApplicationServiceException(
      code: 'workspaceCommandTimedOut',
      message: 'Workspace command timed out.',
      details: <String, Object?>{
        'timeoutMs': timeout.inMilliseconds,
        'command': command.toJson(),
        if (stdout.trim().isNotEmpty) 'stdoutPreview': _outputPreview(stdout),
        if (stderr.trim().isNotEmpty) 'stderrPreview': _outputPreview(stderr),
      },
    );
  } finally {
    await process.exitCode.timeout(
      const Duration(seconds: 2),
      onTimeout: () => -1,
    );
  }
}

String cockpitProcessOutputText(Object? value) {
  if (value is String) {
    return value;
  }
  if (value is List<int>) {
    return utf8.decode(value);
  }
  return '$value';
}

String _outputPreview(String output, {int maxChars = 800}) {
  final normalized = output.trim();
  if (normalized.length <= maxChars) {
    return normalized;
  }
  return '${normalized.substring(0, maxChars).trimRight()}...';
}
