import 'dart:io';

import 'package:args/command_runner.dart';

import '../../application/cockpit_reload_development_session_service.dart';
import '../../development/cockpit_development_session_status.dart';
import '../cockpit_cli_help.dart';
import '../cockpit_command_runner.dart';
import '../cockpit_interactive_cli_support.dart';

typedef CockpitReloadDevelopmentSessionFunction =
    Future<CockpitReloadDevelopmentSessionResult> Function(
      CockpitReloadDevelopmentSessionRequest request,
    );

final class ReloadDevelopmentSessionCommand extends CockpitCliCommand {
  ReloadDevelopmentSessionCommand({
    CockpitReloadDevelopmentSessionService? service,
    CockpitReloadDevelopmentSessionFunction? reload,
    StringSink? stdoutSink,
  }) : _reload =
           reload ??
           (service ?? CockpitReloadDevelopmentSessionService()).reload,
       _stdoutSink = stdoutSink ?? stdout {
    argParser
      ..addOption('session-json', help: cockpitDevelopmentSessionJsonOptionHelp)
      ..addOption(
        'mode',
        allowed: CockpitDevelopmentReloadMode.values
            .map((value) => value.jsonValue)
            .toList(growable: false),
        defaultsTo: CockpitDevelopmentReloadMode.hotReload.jsonValue,
        help: 'Reload mode: hot_reload or hot_restart.',
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
  String get summary => 'Reload development session.';

  @override
  String get category => CockpitCliCategory.coreLoop;

  @override
  String get helpWhen =>
      'Use immediately after code edits in a persistent development session.';

  @override
  String get helpNeeds =>
      'A development session handle from --session-json or the default latest development session handle. Mode defaults to hot_reload.';

  @override
  String get helpExample =>
      'flutter_cockpit_devtools reload-development-session';

  @override
  String get helpWrites =>
      'Updated session status and persisted handle path when available.';

  @override
  Future<int> run() async {
    final result = await _reload(
      CockpitReloadDevelopmentSessionRequest(
        sessionHandlePath: cockpitRequireResolvedDevelopmentSessionHandlePath(
          argResults,
          usage,
        ),
        mode: CockpitDevelopmentReloadMode.fromJson(
          _readRequiredOption('mode'),
        ),
      ),
    );
    await cockpitWriteJsonPayload(
      payload: <String, Object?>{
        'sessionHandle': result.sessionHandle.toJson(),
        'status': result.status.toJson(),
        'persistedHandlePath': result.persistedHandlePath,
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
