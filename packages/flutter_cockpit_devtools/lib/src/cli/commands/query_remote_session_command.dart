import 'dart:io';

import 'package:args/command_runner.dart';

import '../../application/cockpit_query_remote_session_service.dart';
import '../../application/cockpit_session_reference_resolver.dart';
import '../../remote/cockpit_android_port_forwarder.dart';
import '../cockpit_cli_help.dart';
import '../cockpit_command_runner.dart';
import '../cockpit_interactive_cli_support.dart';

final class QueryRemoteSessionCommand extends CockpitCliCommand {
  QueryRemoteSessionCommand({
    CockpitQueryRemoteSessionService? service,
    CockpitAndroidPortForwarder portForwarder =
        const CockpitAndroidPortForwarder(),
    StringSink? stdoutSink,
  }) : _service =
           service ??
           CockpitQueryRemoteSessionService(
             sessionReferenceResolver: CockpitSessionReferenceResolver(
               portForwarder: portForwarder,
             ),
           ),
       _stdoutSink = stdoutSink ?? stdout {
    argParser
      ..addOption('base-url', help: 'Base URL for the running app session.')
      ..addOption('session-json', help: cockpitRemoteSessionJsonOptionHelp)
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
  String get summary => 'Query remote session health.';

  @override
  String get category => CockpitCliCategory.coreLoop;

  @override
  String get helpWhen =>
      'Use when you already have a remote session and need current health or capabilities before the next action.';

  @override
  String get helpNeeds =>
      'Either --session-json, the default latest remote session handle, or --base-url for a reachable app.';

  @override
  String get helpExample => 'flutter_cockpit_devtools query-remote-session';

  @override
  String get helpWrites =>
      'Compact remote health and capability JSON suitable for recovery decisions.';

  @override
  Future<int> run() async {
    final sessionJsonPath = cockpitResolveRemoteSessionHandlePath(argResults);
    final baseUrl = argResults?['base-url'] as String?;
    if ((sessionJsonPath == null || sessionJsonPath.isEmpty) &&
        (baseUrl == null || baseUrl.isEmpty)) {
      throw UsageException(
        '--base-url is required when --session-json is not provided and '
        '${cockpitDefaultRemoteSessionHandlePath()} does not exist.',
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
    await cockpitWriteJsonPayload(
      payload: <String, Object?>{
        'status': result.status.toJson(),
        if (result.sessionHandle != null)
          'sessionHandle': result.sessionHandle!.toJson(),
        'recommendedNextStep': result.recommendedNextStep,
      },
      argResults: argResults,
      stdoutSink: _stdoutSink,
    );

    return cockpitSuccessExitCode;
  }
}
