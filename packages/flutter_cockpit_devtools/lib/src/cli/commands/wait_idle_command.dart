import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';

import '../../application/cockpit_wait_idle_service.dart';
import '../cockpit_command_runner.dart';
import '../cockpit_interactive_cli_support.dart';

typedef CockpitWaitIdleFunction = Future<CockpitWaitIdleResult> Function(
  CockpitWaitIdleRequest request,
);

final class WaitIdleCommand extends Command<int> {
  WaitIdleCommand({
    CockpitWaitIdleService? service,
    CockpitWaitIdleFunction? wait,
    StringSink? stdoutSink,
  })  : _wait = wait ?? (service ?? CockpitWaitIdleService()).wait,
        _stdoutSink = stdoutSink ?? stdout {
    cockpitAddAppArgs(argParser);
    argParser
      ..addOption('quiet-window-ms')
      ..addOption('timeout-ms')
      ..addFlag('include-network-idle', defaultsTo: true);
  }

  final CockpitWaitIdleFunction _wait;
  final StringSink _stdoutSink;

  @override
  String get name => 'wait-idle';

  @override
  String get description => 'Wait for a running app UI to settle.';

  @override
  Future<int> run() async {
    cockpitRequireAppReference(argResults, usage);
    final result = await _wait(
      CockpitWaitIdleRequest(
        baseUri: cockpitReadOptionalBaseUri(argResults),
        appHandlePath: argResults?['app-json'] as String?,
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
