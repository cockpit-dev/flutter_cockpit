import 'dart:convert';
import 'dart:io';

import 'package:flutter_cockpit/flutter_cockpit.dart';

import '../../application/cockpit_interactive_result_profile.dart';
import '../../application/cockpit_read_app_service.dart';
import '../cockpit_cli_help.dart';
import '../cockpit_command_runner.dart';
import '../cockpit_interactive_cli_support.dart';

typedef CockpitReadAppFunction = Future<CockpitReadAppResult> Function(
  CockpitReadAppRequest request,
);

final class ReadAppCommand extends CockpitCliCommand {
  ReadAppCommand({
    CockpitReadAppService? service,
    CockpitReadAppFunction? read,
    StringSink? stdoutSink,
  })  : _read = read ?? (service ?? CockpitReadAppService()).read,
        _stdoutSink = stdoutSink ?? stdout {
    cockpitAddAppArgs(argParser);
    cockpitAddProfileArg(
      argParser,
      defaultProfile: CockpitInteractiveResultProfileName.minimal,
    );
    cockpitAddSnapshotOptionsArgs(argParser);
  }

  final CockpitReadAppFunction _read;
  final StringSink _stdoutSink;

  @override
  String get name => 'read-app';

  @override
  String get description =>
      'Read current app state with the smallest useful result profile.';

  @override
  String get summary => 'Read route and small UI state.';

  @override
  String get category => CockpitCliCategory.coreLoop;

  @override
  String get helpWhen =>
      'Read current route, appId, and a small UI summary before deciding the next step.';

  @override
  String get helpNeeds =>
      'An app reference from --app-json or --base-url. Prefer --profile minimal for routine polling.';

  @override
  String get helpExample =>
      'flutter_cockpit_devtools read-app --app-json /tmp/app.json --profile minimal';

  @override
  String get helpWrites =>
      'Layered JSON with core app state and optional UI summary or snapshotRef.';

  @override
  Future<int> run() async {
    cockpitRequireAppReference(argResults, usage);
    final snapshotOptionsJson = await cockpitReadOptionalJsonObject(
      argResults: argResults,
      inlineOption: 'snapshot-options-json',
      fileOption: 'snapshot-options-file',
      label: 'snapshot options JSON',
      usage: usage,
    );
    final result = await _read(
      CockpitReadAppRequest(
        baseUri: cockpitReadOptionalBaseUri(argResults),
        appHandlePath: argResults?['app-json'] as String?,
        androidDeviceId: argResults?['android-device-id'] as String?,
        resultProfile: cockpitReadResultProfile(
          argResults,
          defaultProfile: CockpitInteractiveResultProfileName.minimal,
        ),
        snapshotOptions: snapshotOptionsJson == null
            ? null
            : CockpitSnapshotOptions.fromJson(snapshotOptionsJson),
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
