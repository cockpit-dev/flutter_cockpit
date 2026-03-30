import 'dart:io';
import 'dart:convert';

import 'package:args/command_runner.dart';

import '../../application/cockpit_interactive_result_profile.dart';
import '../../application/cockpit_read_remote_status_service.dart';
import '../cockpit_command_runner.dart';
import '../cockpit_interactive_cli_support.dart';

typedef CockpitReadRemoteStatusFunction = Future<CockpitReadRemoteStatusResult>
    Function(
  CockpitReadRemoteStatusRequest request,
);

final class ReadRemoteStatusCommand extends Command<int> {
  ReadRemoteStatusCommand({
    CockpitReadRemoteStatusService? service,
    CockpitReadRemoteStatusFunction? read,
    StringSink? stdoutSink,
  })  : _read = read ?? (service ?? CockpitReadRemoteStatusService()).read,
        _stdoutSink = stdoutSink ?? stdout {
    cockpitAddRemoteSessionArgs(argParser);
    cockpitAddProfileArg(
      argParser,
      defaultProfile: CockpitInteractiveResultProfileName.compact,
    );
  }

  final CockpitReadRemoteStatusFunction _read;
  final StringSink _stdoutSink;

  @override
  String get name => 'read-remote-status';

  @override
  String get description =>
      'Read lightweight remote session status with optional richer snapshot layering.';

  @override
  Future<int> run() async {
    cockpitRequireRemoteSessionReference(argResults, usage);
    final result = await _read(
      CockpitReadRemoteStatusRequest(
        baseUri: cockpitReadOptionalBaseUri(argResults),
        sessionHandlePath: argResults?['session-json'] as String?,
        androidDeviceId: argResults?['android-device-id'] as String?,
        resultProfile: cockpitReadResultProfile(
          argResults,
          defaultProfile: CockpitInteractiveResultProfileName.compact,
        ),
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
