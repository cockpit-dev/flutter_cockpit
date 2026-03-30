import '../infrastructure/cockpit_file_system.dart';
import '../infrastructure/cockpit_process_manager.dart';
import '../infrastructure/cockpit_sdk_environment.dart';
import 'cockpit_workspace_command_result.dart';
import 'cockpit_workspace_tooling_support.dart';

final class CockpitFormatWorkspaceRequest {
  const CockpitFormatWorkspaceRequest({
    required this.workspaceRoot,
    this.allowedRoots = const <String>[],
  });

  final String workspaceRoot;
  final List<String> allowedRoots;
}

final class CockpitFormatWorkspaceService {
  CockpitFormatWorkspaceService({
    CockpitFileSystem? fileSystem,
    CockpitProcessManager? processManager,
    CockpitSdkEnvironment? sdkEnvironment,
  })  : _fileSystem = fileSystem ?? const LocalCockpitFileSystem(),
        _processManager = processManager ?? const LocalCockpitProcessManager(),
        _sdkEnvironment = sdkEnvironment ?? const CockpitSdkEnvironment();

  final CockpitFileSystem _fileSystem;
  final CockpitProcessManager _processManager;
  final CockpitSdkEnvironment _sdkEnvironment;

  Future<CockpitWorkspaceCommandResult> format(
    CockpitFormatWorkspaceRequest request,
  ) {
    return runWorkspaceCommand(
      fileSystem: _fileSystem,
      processManager: _processManager,
      sdkEnvironment: _sdkEnvironment,
      workspaceRoot: request.workspaceRoot,
      allowedRoots: request.allowedRoots,
      toolchain: CockpitWorkspaceToolchain.dart,
      dartArguments: const <String>['format', '.'],
    );
  }
}
