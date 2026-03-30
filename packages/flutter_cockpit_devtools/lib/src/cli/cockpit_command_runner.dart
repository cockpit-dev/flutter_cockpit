import 'package:args/command_runner.dart';

import '../application/cockpit_application_service_exception.dart';
import 'commands/hot_reload_command.dart';
import 'commands/hot_restart_command.dart';
import 'commands/inspect_ui_command.dart';
import 'commands/launch_app_command.dart';
import 'commands/list_targets_command.dart';
import 'commands/read_app_command.dart';
import 'commands/read_errors_command.dart';
import 'commands/read_logs_command.dart';
import 'commands/run_batch_command.dart';
import 'commands/run_command_command.dart';
import 'commands/run_script_command.dart';
import 'commands/run_task_command.dart';
import 'commands/serve_mcp_command.dart';
import 'commands/start_recording_command.dart';
import 'commands/stop_app_command.dart';
import 'commands/stop_recording_command.dart';
import 'commands/validate_task_command.dart';
import 'commands/wait_idle_command.dart';

const int cockpitSuccessExitCode = 0;
const int cockpitUsageExitCode = 64;
const int cockpitDataExitCode = 65;
const int cockpitNoInputExitCode = 66;

final class CockpitCommandRunner {
  CockpitCommandRunner()
      : _runner = CommandRunner<int>(
          'flutter_cockpit_devtools',
          'Host-side tooling for flutter_cockpit.',
        )
          ..addCommand(ListTargetsCommand())
          ..addCommand(LaunchAppCommand())
          ..addCommand(ReadAppCommand())
          ..addCommand(InspectUiCommand())
          ..addCommand(RunCommandCommand())
          ..addCommand(RunBatchCommand())
          ..addCommand(HotReloadCommand())
          ..addCommand(HotRestartCommand())
          ..addCommand(StopAppCommand())
          ..addCommand(WaitIdleCommand())
          ..addCommand(StartRecordingCommand())
          ..addCommand(StopRecordingCommand())
          ..addCommand(ReadLogsCommand())
          ..addCommand(ReadErrorsCommand())
          ..addCommand(RunTaskCommand())
          ..addCommand(ValidateTaskCommand())
          ..addCommand(ServeMcpCommand())
          ..addCommand(RunScriptCommand());

  final CommandRunner<int> _runner;

  Future<int> run(List<String> args) async {
    try {
      return await _runner.run(args) ?? cockpitSuccessExitCode;
    } on UsageException {
      return cockpitUsageExitCode;
    } on FormatException {
      return cockpitDataExitCode;
    } on CockpitApplicationServiceException {
      return cockpitDataExitCode;
    } on StateError {
      return cockpitDataExitCode;
    }
  }
}
