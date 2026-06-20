import 'dart:io';

import 'package:args/command_runner.dart';

import '../application/cockpit_application_service_exception.dart';
import '../application/cockpit_compact_json.dart';
import 'cockpit_cli_help.dart';
import 'commands/capture_screenshot_command.dart';
import 'commands/hot_reload_command.dart';
import 'commands/hot_restart_command.dart';
import 'commands/inspect_ui_command.dart';
import 'commands/inspect_surface_command.dart';
import 'commands/collect_development_probe_command.dart';
import 'commands/collect_remote_snapshot_command.dart';
import 'commands/compare_development_probe_command.dart';
import 'commands/execute_remote_command_batch_command.dart';
import 'commands/execute_remote_command_command.dart';
import 'commands/launch_app_command.dart';
import 'commands/launch_development_session_command.dart';
import 'commands/launch_remote_session_command.dart';
import 'commands/launch_target_command.dart';
import 'commands/lsp_command.dart';
import 'commands/list_targets_command.dart';
import 'commands/pub_command.dart';
import 'commands/pub_dev_search_command.dart';
import 'commands/read_app_command.dart';
import 'commands/query_development_session_command.dart';
import 'commands/query_remote_session_command.dart';
import 'commands/read_remote_snapshot_command.dart';
import 'commands/read_remote_status_command.dart';
import 'commands/read_system_capabilities_command.dart';
import 'commands/read_target_command.dart';
import 'commands/read_errors_command.dart';
import 'commands/read_logs_command.dart';
import 'commands/read_network_command.dart';
import 'commands/read_package_uris_command.dart';
import 'commands/read_task_bundle_summary_command.dart';
import 'commands/reload_development_session_command.dart';
import 'commands/run_batch_command.dart';
import 'commands/run_command_command.dart';
import 'commands/run_remote_control_script_command.dart';
import 'commands/run_shell_command.dart';
import 'commands/run_script_command.dart';
import 'commands/run_system_action_command.dart';
import 'commands/run_task_command.dart';
import 'commands/run_tests_command.dart';
import 'commands/serve_mcp_command.dart';
import 'commands/start_recording_command.dart';
import 'commands/start_remote_recording_command.dart';
import 'commands/stop_app_command.dart';
import 'commands/stop_development_session_command.dart';
import 'commands/stop_recording_command.dart';
import 'commands/stop_remote_recording_command.dart';
import 'commands/validate_task_command.dart';
import 'commands/wait_idle_command.dart';
import 'commands/wait_remote_ui_idle_command.dart';
import 'commands/analyze_files_command.dart';
import 'commands/analyze_workspace_command.dart';
import 'commands/apply_fixes_command.dart';
import 'commands/create_project_command.dart';
import 'commands/devtools_command.dart';
import 'commands/format_workspace_command.dart';
import 'commands/grep_package_uris_command.dart';

const int cockpitSuccessExitCode = 0;
const int cockpitUsageExitCode = 64;
const int cockpitDataExitCode = 65;
const int cockpitNoInputExitCode = 66;

final class CockpitCommandRunner {
  CockpitCommandRunner({StringSink? stderrSink, List<Command<int>>? commands})
    : _stderrSink = stderrSink ?? stderr,
      _runner = CockpitCliRootRunner() {
    for (final command in commands ?? _defaultCommands()) {
      _runner.addCommand(command);
    }
  }

  final CommandRunner<int> _runner;
  final StringSink _stderrSink;

  String get usage => _runner.usage;

  Map<String, Command<int>> get commands => _runner.commands;

  Future<int> run(List<String> args) async {
    try {
      return await _runner.run(args) ?? cockpitSuccessExitCode;
    } on UsageException catch (error) {
      _stderrSink.writeln(error);
      _writeErrorJson(code: 'usage', message: error.message);
      return cockpitUsageExitCode;
    } on FormatException catch (error) {
      _stderrSink.writeln('Error: ${error.message}');
      _writeErrorJson(code: 'invalidInput', message: error.message);
      return cockpitDataExitCode;
    } on CockpitApplicationServiceException catch (error) {
      _stderrSink.writeln('Error: ${error.message}');
      _writeErrorJson(
        code: error.code,
        message: error.message,
        details: error.details,
      );
      return cockpitDataExitCode;
    } on StateError catch (error) {
      _stderrSink.writeln('Error: ${error.message}');
      _writeErrorJson(code: 'invalidState', message: error.message);
      return cockpitDataExitCode;
    } on ArgumentError catch (error) {
      final message = _argumentErrorMessage(error);
      _stderrSink.writeln('Error: $message');
      _writeErrorJson(code: 'invalidArgument', message: message);
      return cockpitDataExitCode;
    } on Object catch (error) {
      final message = error.toString();
      _stderrSink.writeln('Error: $message');
      _writeErrorJson(code: 'internalError', message: message);
      return cockpitDataExitCode;
    }
  }

  String _argumentErrorMessage(ArgumentError error) {
    final message = error.message;
    if (message == null) {
      return error.toString();
    }
    return message.toString();
  }

  void _writeErrorJson({
    required String code,
    required String message,
    Map<String, Object?> details = const <String, Object?>{},
  }) {
    _stderrSink.writeln(
      'errorJson: ${cockpitCompactJsonText(<String, Object?>{'code': code, 'message': message, if (details.isNotEmpty) 'details': details})}',
    );
  }

  static List<Command<int>> _defaultCommands() {
    return <Command<int>>[
      ListTargetsCommand(),
      LaunchAppCommand(),
      LaunchTargetCommand(),
      LaunchRemoteSessionCommand(),
      QueryRemoteSessionCommand(),
      ReadRemoteStatusCommand(),
      ReadRemoteSnapshotCommand(),
      CollectRemoteSnapshotCommand(),
      ReadSystemCapabilitiesCommand(),
      ExecuteRemoteCommandCommand(),
      ExecuteRemoteCommandBatchCommand(),
      WaitRemoteUiIdleCommand(),
      ReadAppCommand(),
      ReadTargetCommand(),
      InspectUiCommand(),
      InspectSurfaceCommand(),
      RunCommandCommand(),
      CaptureScreenshotCommand(),
      RunBatchCommand(),
      RunSystemActionCommand(),
      RunShellCommand(),
      HotReloadCommand(),
      HotRestartCommand(),
      StopAppCommand(),
      WaitIdleCommand(),
      PubDevSearchCommand(),
      PubCommand(),
      ReadPackageUrisCommand(),
      GrepPackageUrisCommand(),
      LspCommand(),
      AnalyzeFilesCommand(),
      CreateProjectCommand(),
      AnalyzeWorkspaceCommand(),
      FormatWorkspaceCommand(),
      RunTestsCommand(),
      ApplyFixesCommand(),
      LaunchDevelopmentSessionCommand(),
      QueryDevelopmentSessionCommand(),
      ReloadDevelopmentSessionCommand(),
      CollectDevelopmentProbeCommand(),
      CompareDevelopmentProbeCommand(),
      StopDevelopmentSessionCommand(),
      StartRecordingCommand(),
      StopRecordingCommand(),
      StartRemoteRecordingCommand(),
      StopRemoteRecordingCommand(),
      ReadLogsCommand(),
      ReadNetworkCommand(),
      ReadErrorsCommand(),
      ReadTaskBundleSummaryCommand(),
      RunTaskCommand(),
      ValidateTaskCommand(),
      ServeMcpCommand(),
      DevtoolsCommand(),
      RunScriptCommand(),
      RunRemoteControlScriptCommand(),
    ];
  }
}
