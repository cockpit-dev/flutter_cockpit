import 'package:path/path.dart' as p;

import '../infrastructure/cockpit_file_system.dart';
import '../infrastructure/cockpit_process_manager.dart';
import '../infrastructure/cockpit_sdk_environment.dart';
import 'cockpit_application_service_exception.dart';
import 'cockpit_workspace_command_result.dart';
import 'cockpit_workspace_tooling_support.dart';

enum CockpitProjectTemplate { dartCli, flutterApp }

final class CockpitCreateProjectRequest {
  const CockpitCreateProjectRequest({
    required this.parentDirectory,
    required this.projectName,
    required this.template,
    this.organization,
    this.platforms = const <String>[],
    this.allowedRoots = const <String>[],
    this.timeout = const Duration(minutes: 5),
  });

  final String parentDirectory;
  final String projectName;
  final CockpitProjectTemplate template;
  final String? organization;
  final List<String> platforms;
  final List<String> allowedRoots;
  final Duration timeout;
}

final class CockpitCreateProjectResult {
  const CockpitCreateProjectResult({
    required this.projectDirectory,
    required this.command,
    required this.success,
    required this.stdout,
    required this.stderr,
  });

  final String projectDirectory;
  final CockpitWorkspaceCommand command;
  final bool success;
  final String stdout;
  final String stderr;

  Map<String, Object?> toJson() => <String, Object?>{
    'projectDirectory': projectDirectory,
    'command': command.toJson(),
    'success': success,
    'stdout': stdout,
    'stderr': stderr,
  };
}

final class CockpitCreateProjectService {
  CockpitCreateProjectService({
    CockpitProcessManager? processManager,
    CockpitFileSystem? fileSystem,
    CockpitSdkEnvironment? sdkEnvironment,
  }) : _processManager = processManager ?? const LocalCockpitProcessManager(),
       _fileSystem = fileSystem ?? const LocalCockpitFileSystem(),
       _sdkEnvironment = sdkEnvironment ?? CockpitSdkEnvironment.current();

  final CockpitProcessManager _processManager;
  final CockpitFileSystem _fileSystem;
  final CockpitSdkEnvironment _sdkEnvironment;

  Future<CockpitCreateProjectResult> create(
    CockpitCreateProjectRequest request,
  ) async {
    final parentDirectory = assertWorkspaceRootAllowed(
      request.parentDirectory,
      request.allowedRoots,
    );
    final projectDirectory = p.normalize(
      p.join(parentDirectory, request.projectName),
    );
    assertWorkspaceRootAllowed(projectDirectory, request.allowedRoots);
    _fileSystem.directory(parentDirectory).createSync(recursive: true);

    switch (request.template) {
      case CockpitProjectTemplate.dartCli:
        final result = await runWorkspaceProcess(
          processManager: _processManager,
          executable: _sdkEnvironment.dartExecutable,
          arguments: <String>['create', '--force', request.projectName],
          workingDirectory: parentDirectory,
          timeout: request.timeout,
        );
        return _resultForCommand(
          projectDirectory: projectDirectory,
          result: result,
        );
      case CockpitProjectTemplate.flutterApp:
        final arguments = <String>[
          'create',
          if (request.organization != null) ...<String>[
            '--org',
            request.organization!,
          ],
          if (request.platforms.isNotEmpty)
            '--platforms=${request.platforms.join(',')}',
          projectDirectory,
        ];
        final result = await runWorkspaceProcess(
          processManager: _processManager,
          executable: _sdkEnvironment.flutterExecutable,
          arguments: arguments,
          workingDirectory: parentDirectory,
          timeout: request.timeout,
        );
        return _resultForCommand(
          projectDirectory: projectDirectory,
          result: result,
        );
    }
  }

  CockpitCreateProjectResult _resultForCommand({
    required String projectDirectory,
    required CockpitWorkspaceCommandResult result,
  }) {
    if (!result.success) {
      throw CockpitApplicationServiceException(
        code: 'createProjectFailed',
        message: 'Project creation command failed.',
        details: <String, Object?>{
          'projectDirectory': projectDirectory,
          'command': result.command.toJson(),
          'exitCode': result.exitCode,
          'stdout': result.stdout,
          'stderr': result.stderr,
        },
      );
    }
    return CockpitCreateProjectResult(
      projectDirectory: projectDirectory,
      command: result.command,
      success: true,
      stdout: result.stdout,
      stderr: result.stderr,
    );
  }
}
