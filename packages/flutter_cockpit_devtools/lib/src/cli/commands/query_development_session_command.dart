import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';

import '../../application/cockpit_query_development_session_service.dart';
import '../cockpit_command_runner.dart';

typedef CockpitQueryDevelopmentSessionFunction
    = Future<CockpitQueryDevelopmentSessionResult> Function(
  CockpitQueryDevelopmentSessionRequest request,
);

final class QueryDevelopmentSessionCommand extends Command<int> {
  QueryDevelopmentSessionCommand({
    CockpitQueryDevelopmentSessionService? service,
    CockpitQueryDevelopmentSessionFunction? query,
    StringSink? stdoutSink,
  })  : _query =
            query ?? (service ?? CockpitQueryDevelopmentSessionService()).query,
        _stdoutSink = stdoutSink ?? stdout {
    argParser
      ..addOption(
        'session-json',
        help:
            'Persisted development session handle JSON emitted by launch-development-session.',
      )
      ..addOption(
        'output-json',
        help: 'Optional file path where the status payload should be written.',
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
  Future<int> run() async {
    final sessionJsonPath = _readRequiredOption('session-json');
    final result = await _query(
      CockpitQueryDevelopmentSessionRequest(sessionHandlePath: sessionJsonPath),
    );
    final payload =
        const JsonEncoder.withIndent('  ').convert(<String, Object?>{
      'status': result.status.toJson(),
      'sessionHandle': result.sessionHandle?.toJson(),
      'recommendedNextStep': result.recommendedNextStep,
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
