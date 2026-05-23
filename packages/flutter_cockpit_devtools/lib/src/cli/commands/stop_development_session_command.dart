import 'dart:io';

import '../../application/cockpit_stop_development_session_service.dart';
import '../cockpit_cli_help.dart';
import '../cockpit_command_runner.dart';
import '../cockpit_interactive_cli_support.dart';

typedef CockpitStopDevelopmentSessionFunction =
    Future<CockpitStopDevelopmentSessionResult> Function(
      CockpitStopDevelopmentSessionRequest request,
    );

final class StopDevelopmentSessionCommand extends CockpitCliCommand {
  StopDevelopmentSessionCommand({
    CockpitStopDevelopmentSessionService? service,
    CockpitStopDevelopmentSessionFunction? stop,
    StringSink? stdoutSink,
  }) : _stop = stop ?? (service ?? CockpitStopDevelopmentSessionService()).stop,
       _stdoutSink = stdoutSink ?? stdout {
    argParser.addOption(
      'session-json',
      help: cockpitDevelopmentSessionJsonOptionHelp,
    );
  }

  final CockpitStopDevelopmentSessionFunction _stop;
  final StringSink _stdoutSink;

  @override
  String get name => 'stop-development-session';

  @override
  String get description => 'Stop a running development session supervisor.';

  @override
  String get summary => 'Stop development session.';

  @override
  String get category => CockpitCliCategory.coreLoop;

  @override
  String get helpWhen =>
      'Use at the end of a persistent development loop to stop the supervisor and app.';

  @override
  String get helpNeeds =>
      'A development session handle from --session-json or the default latest development session handle.';

  @override
  String get helpExample => 'flutter_cockpit_devtools stop-development-session';

  @override
  String get helpWrites =>
      'Stopped session handle and final supervisor status.';

  @override
  Future<int> run() async {
    final result = await _stop(
      CockpitStopDevelopmentSessionRequest(
        sessionHandlePath: cockpitRequireResolvedDevelopmentSessionHandlePath(
          argResults,
          usage,
        ),
      ),
    );
    await cockpitWriteJsonPayload(
      payload: <String, Object?>{
        'sessionHandle': result.sessionHandle.toJson(),
        'status': result.status.toJson(),
      },
      argResults: argResults,
      stdoutSink: _stdoutSink,
    );
    return cockpitSuccessExitCode;
  }
}
