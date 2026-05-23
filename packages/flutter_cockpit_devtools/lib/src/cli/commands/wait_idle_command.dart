import 'dart:convert';
import 'dart:io';

import '../../application/cockpit_wait_idle_service.dart';
import '../cockpit_cli_help.dart';
import '../cockpit_command_runner.dart';
import '../cockpit_interactive_cli_support.dart';

typedef CockpitWaitIdleFunction =
    Future<CockpitWaitIdleResult> Function(CockpitWaitIdleRequest request);

final class WaitIdleCommand extends CockpitCliCommand {
  WaitIdleCommand({
    CockpitWaitIdleService? service,
    CockpitWaitIdleFunction? wait,
    StringSink? stdoutSink,
  }) : _wait = wait ?? (service ?? CockpitWaitIdleService()).wait,
       _stdoutSink = stdoutSink ?? stdout {
    cockpitAddAppArgs(argParser);
    argParser
      ..addOption(
        'quiet-window-ms',
        help:
            'How long the UI must stay quiet before the app is considered idle.',
      )
      ..addOption(
        'timeout-ms',
        help: 'Maximum wait time before the command returns a timeout result.',
      )
      ..addFlag(
        'include-network-idle',
        defaultsTo: true,
        help:
            'Also require tracked network activity to go idle before succeeding.',
      );
  }

  final CockpitWaitIdleFunction _wait;
  final StringSink _stdoutSink;

  @override
  String get name => 'wait-idle';

  @override
  String get description => 'Wait for a running app UI to settle.';

  @override
  String get summary => 'Wait until UI settles.';

  @override
  String get category => CockpitCliCategory.coreLoop;

  @override
  String get helpWhen =>
      'Pause until the app stops changing before the next read, assertion, or capture.';

  @override
  String get helpNeeds =>
      'An app reference. Tune quiet-window-ms or timeout-ms only when the defaults are too short.';

  @override
  String get helpExample =>
      'flutter_cockpit_devtools wait-idle --app-json /tmp/app.json';

  @override
  String get helpWrites =>
      'An idle verdict with quiet-window timing and optional network-idle detail.';

  @override
  Future<int> run() async {
    cockpitRequireAppReference(argResults, usage);
    final result = await _wait(
      CockpitWaitIdleRequest(
        baseUri: cockpitReadOptionalBaseUri(argResults),
        appHandlePath: cockpitResolveAppHandlePath(argResults),
        androidDeviceId: argResults?['android-device-id'] as String?,
        quietWindow: Duration(
          milliseconds:
              cockpitReadOptionalPositiveInt(
                argResults,
                'quiet-window-ms',
                usage,
              ) ??
              96,
        ),
        timeout: Duration(
          milliseconds:
              cockpitReadOptionalPositiveInt(argResults, 'timeout-ms', usage) ??
              1600,
        ),
        includeNetworkIdle:
            argResults?['include-network-idle'] as bool? ?? true,
      ),
    );
    await cockpitWriteJsonPayload(
      payload: const JsonEncoder.withIndent('  ').convert(result.toJson()),
      argResults: argResults,
      stdoutSink: _stdoutSink,
    );
    return cockpitSuccessExitCode;
  }
}
