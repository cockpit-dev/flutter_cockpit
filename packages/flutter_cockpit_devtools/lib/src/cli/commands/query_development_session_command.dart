import 'dart:io';

import '../../application/cockpit_query_development_session_service.dart';
import '../cockpit_cli_help.dart';
import '../cockpit_command_runner.dart';
import '../cockpit_interactive_cli_support.dart';

typedef CockpitQueryDevelopmentSessionFunction =
    Future<CockpitQueryDevelopmentSessionResult> Function(
      CockpitQueryDevelopmentSessionRequest request,
    );

final class QueryDevelopmentSessionCommand extends CockpitCliCommand {
  QueryDevelopmentSessionCommand({
    CockpitQueryDevelopmentSessionService? service,
    CockpitQueryDevelopmentSessionFunction? query,
    StringSink? stdoutSink,
  }) : _query =
           query ?? (service ?? CockpitQueryDevelopmentSessionService()).query,
       _stdoutSink = stdoutSink ?? stdout {
    argParser.addOption(
      'session-json',
      help: cockpitDevelopmentSessionJsonOptionHelp,
    );
  }

  final CockpitQueryDevelopmentSessionFunction _query;
  final StringSink _stdoutSink;

  @override
  String get name => 'query-development-session';

  @override
  String get description =>
      'Read current lifecycle status for a running development session.';

  @override
  String get summary => 'Query development session.';

  @override
  String get category => CockpitCliCategory.coreLoop;

  @override
  String get helpWhen =>
      'Use before reload, probe, or cleanup when you need current supervisor status.';

  @override
  String get helpNeeds =>
      'A development session handle from --session-json or the default latest development session handle.';

  @override
  String get helpExample =>
      'flutter_cockpit_devtools query-development-session';

  @override
  String get helpWrites =>
      'Current development session status, refreshed handle data, and recommended next step.';

  @override
  Future<int> run() async {
    final sessionJsonPath = cockpitRequireResolvedDevelopmentSessionHandlePath(
      argResults,
      usage,
    );
    final result = await _query(
      CockpitQueryDevelopmentSessionRequest(sessionHandlePath: sessionJsonPath),
    );
    await cockpitWriteJsonPayload(
      payload: <String, Object?>{
        'status': result.status.toJson(),
        'sessionHandle': result.sessionHandle?.toJson(),
        'recommendedNextStep': result.recommendedNextStep,
      },
      argResults: argResults,
      stdoutSink: _stdoutSink,
    );
    return cockpitSuccessExitCode;
  }
}
