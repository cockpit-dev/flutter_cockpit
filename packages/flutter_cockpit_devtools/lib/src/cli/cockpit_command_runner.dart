import 'dart:io';

import 'package:args/command_runner.dart';

import '../application/cockpit_application_service_exception.dart';
import 'cockpit_cli_help.dart';
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
  CockpitCommandRunner({StringSink? stderrSink})
      : _stderrSink = stderrSink ?? stderr,
        _runner = CockpitCliRootRunner()
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
  final StringSink _stderrSink;

  String get usage => _runner.usage;

  Map<String, Command<int>> get commands => _runner.commands;

  Future<int> run(List<String> args) async {
    try {
      return await _runner.run(args) ?? cockpitSuccessExitCode;
    } on UsageException catch (error) {
      _stderrSink.writeln(error);
      return cockpitUsageExitCode;
    } on FormatException catch (error) {
      _stderrSink.writeln('Error: ${error.message}');
      return cockpitDataExitCode;
    } on CockpitApplicationServiceException catch (error) {
      _stderrSink.writeln('Error: ${error.message}');
      return cockpitDataExitCode;
    } on StateError catch (error) {
      _stderrSink.writeln('Error: ${error.message}');
      return cockpitDataExitCode;
    }
  }
}
