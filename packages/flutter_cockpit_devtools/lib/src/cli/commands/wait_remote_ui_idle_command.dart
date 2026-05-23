import 'dart:io';
import 'dart:convert';

import '../../application/cockpit_wait_remote_ui_idle_service.dart';
import '../cockpit_cli_help.dart';
import '../cockpit_command_runner.dart';
import '../cockpit_interactive_cli_support.dart';

typedef CockpitWaitRemoteUiIdleFunction =
    Future<CockpitWaitRemoteUiIdleResult> Function(
      CockpitWaitRemoteUiIdleRequest request,
    );

final class WaitRemoteUiIdleCommand extends CockpitCliCommand {
  WaitRemoteUiIdleCommand({
    CockpitWaitRemoteUiIdleService? service,
    CockpitWaitRemoteUiIdleFunction? wait,
    StringSink? stdoutSink,
  }) : _wait = wait ?? (service ?? CockpitWaitRemoteUiIdleService()).wait,
       _stdoutSink = stdoutSink ?? stdout {
    cockpitAddRemoteSessionArgs(argParser);
    argParser
      ..addOption(
        'quiet-window-ms',
        help: 'Required quiet period before the UI is considered idle.',
      )
      ..addOption(
        'timeout-ms',
        help: 'Maximum wait time before returning not-idle.',
      )
      ..addFlag(
        'include-network-idle',
        defaultsTo: true,
        negatable: true,
        help: 'Also wait for captured in-flight network activity to settle.',
      );
  }

  final CockpitWaitRemoteUiIdleFunction _wait;
  final StringSink _stdoutSink;

  @override
  String get name => 'wait-remote-ui-idle';

  @override
  String get description =>
      'Wait for the remote UI to settle before the next interactive action.';

  @override
  String get summary => 'Wait remote UI idle.';

  @override
  String get category => CockpitCliCategory.coreLoop;

  @override
  String get helpWhen =>
      'Use between route-changing or async remote actions before reading or asserting state.';

  @override
  String get helpNeeds => 'Either --session-json or --base-url.';

  @override
  String get helpExample =>
      'flutter_cockpit_devtools wait-remote-ui-idle --session-json /tmp/session.json --timeout-ms 1600';

  @override
  String get helpWrites =>
      'A compact idle result with elapsed time and next-step guidance.';

  @override
  Future<int> run() async {
    cockpitRequireRemoteSessionReference(argResults, usage);
    final result = await _wait(
      CockpitWaitRemoteUiIdleRequest(
        baseUri: cockpitReadOptionalBaseUri(argResults),
        sessionHandlePath: cockpitResolveRemoteSessionHandlePath(argResults),
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
