import 'dart:io';

import 'package:args/command_runner.dart';

import '../../application/cockpit_compact_json.dart';
import '../../application/cockpit_reload_development_session_service.dart';
import '../../development/cockpit_development_session_status.dart';
import '../cockpit_command_runner.dart';

typedef CockpitReloadDevelopmentSessionFunction
    = Future<CockpitReloadDevelopmentSessionResult> Function(
  CockpitReloadDevelopmentSessionRequest request,
);

final class ReloadDevelopmentSessionCommand extends Command<int> {
  ReloadDevelopmentSessionCommand({
    CockpitReloadDevelopmentSessionService? service,
    CockpitReloadDevelopmentSessionFunction? reload,
    StringSink? stdoutSink,
  })  : _reload = reload ??
            (service ?? CockpitReloadDevelopmentSessionService()).reload,
        _stdoutSink = stdoutSink ?? stdout {
    argParser
      ..addOption(
        'session-json',
        help: 'Persisted development session handle JSON to reload.',
      )
      ..addOption(
        'mode',
        allowed: CockpitDevelopmentReloadMode.values
            .map((value) => value.jsonValue)
            .toList(growable: false),
        defaultsTo: CockpitDevelopmentReloadMode.hotReload.jsonValue,
        help: 'Reload mode: hot_reload or hot_restart.',
      )
      ..addOption(
        'output-json',
        help: 'Optional file path where the updated payload should be written.',
      );
  }

  final CockpitReloadDevelopmentSessionFunction _reload;
  final StringSink _stdoutSink;

  @override
  String get name => 'reload-development-session';

  @override
  String get description =>
      'Trigger hot reload or hot restart for an existing development session.';

  @override
  Future<int> run() async {
    final result = await _reload(
      CockpitReloadDevelopmentSessionRequest(
        sessionHandlePath: _readRequiredOption('session-json'),
        mode: CockpitDevelopmentReloadMode.fromJson(
          _readRequiredOption('mode'),
        ),
      ),
    );
    final payload = cockpitPrettyJsonText(<String, Object?>{
      'sessionHandle': result.sessionHandle.toJson(),
      'status': result.status.toJson(),
      'persistedHandlePath': result.persistedHandlePath,
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
