import 'dart:io';
import 'dart:convert';

import 'package:args/command_runner.dart';

import '../../application/cockpit_wait_remote_ui_idle_service.dart';
import '../cockpit_command_runner.dart';
import '../cockpit_interactive_cli_support.dart';

typedef CockpitWaitRemoteUiIdleFunction = Future<CockpitWaitRemoteUiIdleResult>
    Function(
  CockpitWaitRemoteUiIdleRequest request,
);

final class WaitRemoteUiIdleCommand extends Command<int> {
  WaitRemoteUiIdleCommand({
    CockpitWaitRemoteUiIdleService? service,
    CockpitWaitRemoteUiIdleFunction? wait,
    StringSink? stdoutSink,
  })  : _wait = wait ?? (service ?? CockpitWaitRemoteUiIdleService()).wait,
        _stdoutSink = stdoutSink ?? stdout {
    cockpitAddRemoteSessionArgs(argParser);
    argParser
      ..addOption('quiet-window-ms')
      ..addOption('timeout-ms')
      ..addFlag('include-network-idle', defaultsTo: true, negatable: true);
  }

  final CockpitWaitRemoteUiIdleFunction _wait;
  final StringSink _stdoutSink;

  @override
  String get name => 'wait-remote-ui-idle';

  @override
  String get description =>
      'Wait for the remote UI to settle before the next interactive action.';

  @override
  Future<int> run() async {
    cockpitRequireRemoteSessionReference(argResults, usage);
    final result = await _wait(
      CockpitWaitRemoteUiIdleRequest(
        baseUri: cockpitReadOptionalBaseUri(argResults),
        sessionHandlePath: argResults?['session-json'] as String?,
        androidDeviceId: argResults?['android-device-id'] as String?,
        quietWindow: Duration(
          milliseconds:
              cockpitReadOptionalInt(argResults, 'quiet-window-ms') ?? 96,
        ),
        timeout: Duration(
          milliseconds:
              cockpitReadOptionalInt(argResults, 'timeout-ms') ?? 1600,
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
