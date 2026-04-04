import 'dart:io';

import 'package:args/command_runner.dart';

import '../../application/cockpit_stop_development_session_service.dart';
import '../../application/cockpit_json_key_normalizer.dart';
import '../cockpit_command_runner.dart';

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
    final payload = cockpitPrettyJsonText(<String, Object?>{
      'sessionHandle': result.sessionHandle.toJson(),
      'status': result.status.toJson(),
    });
    final outputJson = argResults?['output-json'] as String?;
    if (outputJson == null || outputJson.isEmpty) {
      _stdoutSink.writeln(payload);
    } else {
      final file = File(outputJson);
      await file.parent.create(recursive: true);
      await file.writeAsString(payload);
    }
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
