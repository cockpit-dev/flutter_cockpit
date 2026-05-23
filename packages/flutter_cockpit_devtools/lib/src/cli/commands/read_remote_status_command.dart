import 'dart:io';
import 'dart:convert';

import '../../application/cockpit_interactive_result_profile.dart';
import '../../application/cockpit_read_remote_status_service.dart';
import '../cockpit_cli_help.dart';
import '../cockpit_command_runner.dart';
import '../cockpit_interactive_cli_support.dart';

typedef CockpitReadRemoteStatusFunction = Future<CockpitReadRemoteStatusResult>
    Function(
  CockpitReadRemoteStatusRequest request,
);

final class ReadRemoteStatusCommand extends CockpitCliCommand {
  ReadRemoteStatusCommand({
    CockpitReadRemoteStatusService? service,
    CockpitReadRemoteStatusFunction? read,
    StringSink? stdoutSink,
  })  : _read = read ?? (service ?? CockpitReadRemoteStatusService()).read,
        _stdoutSink = stdoutSink ?? stdout {
    cockpitAddRemoteSessionArgs(argParser);
    cockpitAddProfileArg(
      argParser,
      defaultProfile: CockpitInteractiveResultProfileName.minimal,
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
  String get summary => 'Read remote status.';

  @override
  String get category => CockpitCliCategory.coreLoop;

  @override
  String get helpWhen =>
      'Use before or after a remote command when minimal health and route context is enough.';

  @override
  String get helpNeeds =>
      'Either --session-json or --base-url. Keep --profile minimal unless you need more detail.';

  @override
  String get helpExample =>
      'flutter_cockpit_devtools read-remote-status --session-json /tmp/session.json --profile minimal';

  @override
  String get helpWrites =>
      'Layered status JSON with compact capability, route, and optional snapshot details.';

  @override
  Future<int> run() async {
    cockpitRequireRemoteSessionReference(argResults, usage);
    final result = await _read(
      CockpitReadRemoteStatusRequest(
        baseUri: cockpitReadOptionalBaseUri(argResults),
        sessionHandlePath: cockpitResolveRemoteSessionHandlePath(argResults),
        androidDeviceId: argResults?['android-device-id'] as String?,
        resultProfile: cockpitReadResultProfile(
          argResults,
          defaultProfile: CockpitInteractiveResultProfileName.minimal,
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
