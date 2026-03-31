import '../infrastructure/cockpit_file_system.dart';
import '../infrastructure/cockpit_process_manager.dart';
import '../infrastructure/cockpit_sdk_environment.dart';
import 'cockpit_application_service_exception.dart';
import 'cockpit_workspace_command_result.dart';
import 'cockpit_workspace_tooling_support.dart';

enum CockpitPubCommand { add, deps, get, outdated, remove, upgrade }

final class CockpitPubRequest {
  const CockpitPubRequest({
    required this.workspaceRoot,
    required this.command,
    this.packages = const <String>[],
    this.allowedRoots = const <String>[],
    this.maxOutputChars = 1600,
    this.timeout = const Duration(minutes: 4),
  });

  final String workspaceRoot;
  final CockpitPubCommand command;
  final List<String> packages;
  final List<String> allowedRoots;
  final int maxOutputChars;
  final Duration timeout;
}

final class CockpitPubResult {
  const CockpitPubResult({
    required this.workspaceRoot,
    required this.toolchain,
    required this.pubCommand,
    required this.packages,
    required this.command,
    required this.exitCode,
    required this.success,
    required this.summary,
    this.stdoutPreview,
    this.stdoutTruncated = false,
    this.stdoutLineCount = 0,
    this.stderrPreview,
    this.stderrTruncated = false,
    this.stderrLineCount = 0,
  });

  final String workspaceRoot;
  final CockpitWorkspaceToolchain toolchain;
  final CockpitPubCommand pubCommand;
  final List<String> packages;
  final CockpitWorkspaceCommand command;
  final int exitCode;
  final bool success;
  final String summary;
  final String? stdoutPreview;
  final bool stdoutTruncated;
  final int stdoutLineCount;
  final String? stderrPreview;
  final bool stderrTruncated;
  final int stderrLineCount;

  Map<String, Object?> toJson() => <String, Object?>{
        'workspace_root': workspaceRoot,
        'toolchain': toolchain.name,
        'pub_command': pubCommand.name,
        'packages': packages,
        'command': command.toJson(),
        'exit_code': exitCode,
        'success': success,
        'summary': summary,
        if (stdoutPreview != null) 'stdout_preview': stdoutPreview,
        'stdout_truncated': stdoutTruncated,
        'stdout_line_count': stdoutLineCount,
        if (stderrPreview != null) 'stderr_preview': stderrPreview,
        'stderr_truncated': stderrTruncated,
        'stderr_line_count': stderrLineCount,
      };
}

final class CockpitPubService {
  CockpitPubService({
    CockpitFileSystem? fileSystem,
    CockpitProcessManager? processManager,
    CockpitSdkEnvironment? sdkEnvironment,
  })  : _fileSystem = fileSystem ?? const LocalCockpitFileSystem(),
        _processManager = processManager ?? const LocalCockpitProcessManager(),
        _sdkEnvironment = sdkEnvironment ?? const CockpitSdkEnvironment();

  final CockpitFileSystem _fileSystem;
  final CockpitProcessManager _processManager;
  final CockpitSdkEnvironment _sdkEnvironment;

  Future<CockpitPubResult> run(CockpitPubRequest request) async {
    final workspaceRoot = assertWorkspaceRootAllowed(
      request.workspaceRoot,
      request.allowedRoots,
    );
    _validatePackages(request.command, request.packages);

    final toolchain = detectWorkspaceToolchain(_fileSystem, workspaceRoot);
    final commandArguments = <String>[
      'pub',
      request.command.name,
      ...request.packages,
    ];
    final result = await runWorkspaceCommand(
      fileSystem: _fileSystem,
      processManager: _processManager,
      sdkEnvironment: _sdkEnvironment,
      workspaceRoot: workspaceRoot,
      allowedRoots: request.allowedRoots,
      toolchain: toolchain,
      dartArguments: commandArguments,
      flutterArguments: commandArguments,
      timeout: request.timeout,
    );
    final stdout = _excerpt(result.stdout, maxChars: request.maxOutputChars);
    final stderr = _excerpt(result.stderr, maxChars: request.maxOutputChars);
    return CockpitPubResult(
      workspaceRoot: workspaceRoot,
      toolchain: toolchain,
      pubCommand: request.command,
      packages: List<String>.unmodifiable(request.packages),
      command: result.command,
      exitCode: result.exitCode,
      success: result.success,
      summary: _summaryFor(result),
      stdoutPreview: stdout.preview,
      stdoutTruncated: stdout.truncated,
      stdoutLineCount: stdout.lineCount,
      stderrPreview: stderr.preview,
      stderrTruncated: stderr.truncated,
      stderrLineCount: stderr.lineCount,
    );
  }

  void _validatePackages(
    CockpitPubCommand command,
    List<String> packages,
  ) {
    final requiresPackages = switch (command) {
      CockpitPubCommand.add || CockpitPubCommand.remove => true,
      CockpitPubCommand.deps ||
      CockpitPubCommand.get ||
      CockpitPubCommand.outdated ||
      CockpitPubCommand.upgrade =>
        false,
    };
    if (requiresPackages && packages.isEmpty) {
      throw CockpitApplicationServiceException(
        code: 'pubPackagesRequired',
        message: 'packages is required for this pub command.',
        details: <String, Object?>{
          'command': command.name,
        },
      );
    }
    if (!requiresPackages && packages.isNotEmpty) {
      throw CockpitApplicationServiceException(
        code: 'pubPackagesNotAllowed',
        message: 'packages is only supported for add and remove.',
        details: <String, Object?>{
          'command': command.name,
          'packages': packages,
        },
      );
    }
  }
}

String _summaryFor(CockpitWorkspaceCommandResult result) {
  final preferredOutput = result.success ? result.stdout : result.stderr;
  for (final line in preferredOutput.split('\n')) {
    final trimmed = line.trim();
    if (trimmed.isNotEmpty) {
      return trimmed;
    }
  }
  return result.success
      ? 'pub command completed.'
      : 'pub command failed with exit code ${result.exitCode}.';
}

({String? preview, bool truncated, int lineCount}) _excerpt(
  String raw, {
  required int maxChars,
}) {
  final normalized = raw.trim();
  if (normalized.isEmpty) {
    return (preview: null, truncated: false, lineCount: 0);
  }
  final lineCount = '\n'.allMatches(normalized).length + 1;
  if (normalized.length <= maxChars) {
    return (preview: normalized, truncated: false, lineCount: lineCount);
  }
  final safeMax = maxChars < 1 ? 1 : maxChars;
  final clipped = normalized.substring(0, safeMax).trimRight();
  return (
    preview: '$clipped...',
    truncated: true,
    lineCount: lineCount,
  );
}
