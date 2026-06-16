import '../infrastructure/cockpit_file_system.dart';
import '../infrastructure/cockpit_process_manager.dart';
import '../infrastructure/cockpit_sdk_environment.dart';
import 'cockpit_workspace_command_result.dart';
import 'cockpit_workspace_tooling_support.dart';

final class CockpitApplyWorkspaceFixesRequest {
  const CockpitApplyWorkspaceFixesRequest({
    required this.workspaceRoot,
    this.allowedRoots = const <String>[],
    this.timeout = const Duration(minutes: 3),
  });

  final String workspaceRoot;
  final List<String> allowedRoots;
  final Duration timeout;
}

final class CockpitApplyWorkspaceFixesService {
  CockpitApplyWorkspaceFixesService({
    CockpitFileSystem? fileSystem,
    CockpitProcessManager? processManager,
    CockpitSdkEnvironment? sdkEnvironment,
  }) : _fileSystem = fileSystem ?? const LocalCockpitFileSystem(),
       _processManager = processManager ?? const LocalCockpitProcessManager(),
       _sdkEnvironment = sdkEnvironment ?? CockpitSdkEnvironment.current();

  final CockpitFileSystem _fileSystem;
  final CockpitProcessManager _processManager;
  final CockpitSdkEnvironment _sdkEnvironment;

  Future<CockpitWorkspaceCommandResult> apply(
    CockpitApplyWorkspaceFixesRequest request,
  ) {
    return runWorkspaceCommand(
      fileSystem: _fileSystem,
      processManager: _processManager,
      sdkEnvironment: _sdkEnvironment,
      workspaceRoot: request.workspaceRoot,
      allowedRoots: request.allowedRoots,
      toolchain: CockpitWorkspaceToolchain.dart,
      dartArguments: const <String>['fix', '--apply'],
      timeout: request.timeout,
    );
  }
}
