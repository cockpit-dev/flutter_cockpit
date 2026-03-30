import 'package:args/command_runner.dart';

import '../adapters/cockpit_automation_adapter.dart';
import '../adapters/cockpit_capture_adapter.dart';
import '../application/cockpit_application_service_exception.dart';
import '../artifacts/task_run_bundle_writer.dart';
import 'commands/bundle_session_command.dart';
import 'commands/collect_development_probe_command.dart';
import 'commands/collect_remote_snapshot_command.dart';
import 'commands/compare_development_probe_command.dart';
import 'commands/execute_remote_command_batch_command.dart';
import 'commands/execute_remote_command_command.dart';
import 'commands/launch_development_session_command.dart';
import 'commands/launch_remote_session_command.dart';
import 'commands/read_remote_snapshot_command.dart';
import 'commands/read_remote_status_command.dart';
import 'commands/query_development_session_command.dart';
import 'commands/query_remote_session_command.dart';
import 'commands/reload_development_session_command.dart';
import 'commands/run_control_script_command.dart';
import 'commands/run_remote_control_script_command.dart';
import 'commands/run_task_command.dart';
import 'commands/serve_mcp_command.dart';
import 'commands/start_remote_recording_command.dart';
import 'commands/stop_development_session_command.dart';
import 'commands/stop_remote_recording_command.dart';
import 'commands/validate_task_command.dart';
import 'commands/wait_remote_ui_idle_command.dart';

const int cockpitSuccessExitCode = 0;
const int cockpitUsageExitCode = 64;
const int cockpitDataExitCode = 65;
const int cockpitNoInputExitCode = 66;

final class CockpitCommandRunner {
  CockpitCommandRunner({
    CockpitAutomationAdapter? automationAdapter,
    CockpitCaptureAdapter? captureAdapter,
    TaskRunBundleWriter writer = const TaskRunBundleWriter(),
  }) : _runner = CommandRunner<int>(
          'flutter_cockpit_devtools',
          'Host-side tooling for flutter_cockpit.',
        )
          ..addCommand(BundleSessionCommand(writer: writer))
          ..addCommand(CollectDevelopmentProbeCommand())
          ..addCommand(CollectRemoteSnapshotCommand())
          ..addCommand(CompareDevelopmentProbeCommand())
          ..addCommand(ExecuteRemoteCommandCommand())
          ..addCommand(ExecuteRemoteCommandBatchCommand())
          ..addCommand(LaunchDevelopmentSessionCommand())
          ..addCommand(LaunchRemoteSessionCommand())
          ..addCommand(ReadRemoteStatusCommand())
          ..addCommand(ReadRemoteSnapshotCommand())
          ..addCommand(QueryDevelopmentSessionCommand())
          ..addCommand(QueryRemoteSessionCommand())
          ..addCommand(ReloadDevelopmentSessionCommand())
          ..addCommand(RunTaskCommand())
          ..addCommand(StopDevelopmentSessionCommand())
          ..addCommand(StartRemoteRecordingCommand())
          ..addCommand(StopRemoteRecordingCommand())
          ..addCommand(ValidateTaskCommand())
          ..addCommand(WaitRemoteUiIdleCommand())
          ..addCommand(ServeMcpCommand())
          ..addCommand(
            RunControlScriptCommand(
              automationAdapter: automationAdapter,
              captureAdapter: captureAdapter,
              writer: writer,
            ),
          )
          ..addCommand(RunRemoteControlScriptCommand(writer: writer));

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
