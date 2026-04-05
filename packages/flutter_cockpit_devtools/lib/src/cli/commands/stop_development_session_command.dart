import 'dart:io';

import 'package:args/command_runner.dart';

import '../../application/cockpit_stop_development_session_service.dart';
import '../cockpit_command_runner.dart';
import '../cockpit_interactive_cli_support.dart';

typedef CockpitStopDevelopmentSessionFunction
    = Future<CockpitStopDevelopmentSessionResult> Function(
  CockpitStopDevelopmentSessionRequest request,
);

final class StopDevelopmentSessionCommand extends Command<int> {
  StopDevelopmentSessionCommand({
    CockpitStopDevelopmentSessionService? service,
    CockpitStopDevelopmentSessionFunction? stop,
    StringSink? stdoutSink,
  })  : _stop =
            stop ?? (service ?? CockpitStopDevelopmentSessionService()).stop,
        _stdoutSink = stdoutSink ?? stdout {
    argParser
      ..addOption(
        'session-json',
        help: 'Persisted development session handle JSON to stop.',
      )
      ..addOption(
        'output-json',
        help: 'Optional file path where the stopped payload should be written.',
      );
  }

  final CockpitStopDevelopmentSessionFunction _stop;
  final StringSink _stdoutSink;

  @override
  String get name => 'stop-development-session';

  @override
  String get description => 'Stop a running development session supervisor.';

  @override
  Future<int> run() async {
    final result = await _stop(
      CockpitStopDevelopmentSessionRequest(
        sessionHandlePath: _readRequiredOption('session-json'),
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

  String _readRequiredOption(String name) {
    final value = argResults?[name] as String?;
    if (value == null || value.isEmpty) {
      throw UsageException('--$name is required.', usage);
    }
    return value;
  }
}
