import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';

import '../../application/cockpit_query_remote_session_service.dart';
import '../../application/cockpit_session_reference_resolver.dart';
import '../../remote/cockpit_android_port_forwarder.dart';
import '../cockpit_command_runner.dart';

final class QueryRemoteSessionCommand extends Command<int> {
  QueryRemoteSessionCommand({
    CockpitQueryRemoteSessionService? service,
    CockpitAndroidPortForwarder portForwarder =
        const CockpitAndroidPortForwarder(),
    StringSink? stdoutSink,
  })  : _service = service ??
            CockpitQueryRemoteSessionService(
              sessionReferenceResolver: CockpitSessionReferenceResolver(
                portForwarder: portForwarder,
              ),
            ),
        _stdoutSink = stdoutSink ?? stdout {
    argParser
      ..addOption('base-url', help: 'Base URL for the running app session.')
      ..addOption(
        'session-json',
        help:
            'Optional session handle JSON file emitted by launch-remote-session.',
      )
      ..addOption(
        'output-json',
        help: 'Optional file path where the session payload should be written.',
      )
      ..addOption(
        'android-device-id',
        help: 'Optional Android device ID used to set up adb port forwarding.',
      );
  }

  final CockpitQueryRemoteSessionService _service;
  final StringSink _stdoutSink;

  @override
  String get name => 'query-remote-session';

  @override
  String get description =>
      'Query a running flutter_cockpit remote session and return its health payload.';

  @override
  Future<int> run() async {
    final sessionJsonPath = argResults?['session-json'] as String?;
    final baseUrl = argResults?['base-url'] as String?;
    if ((sessionJsonPath == null || sessionJsonPath.isEmpty) &&
        (baseUrl == null || baseUrl.isEmpty)) {
      throw UsageException(
        '--base-url is required when --session-json is not provided.',
        usage,
      );
    }

    final result = await _service.query(
      CockpitQueryRemoteSessionRequest(
        baseUri: baseUrl == null || baseUrl.isEmpty ? null : Uri.parse(baseUrl),
        sessionHandlePath: sessionJsonPath,
        androidDeviceId: argResults?['android-device-id'] as String?,
      ),
    );
    final payload = jsonEncode(result.status.toJson());
    final outputJson = argResults?['output-json'] as String?;

    if (outputJson == null || outputJson.isEmpty) {
      _stdoutSink.writeln(payload);
    } else {
      await File(outputJson).writeAsString(payload);
    }

    return cockpitSuccessExitCode;
  }
}
