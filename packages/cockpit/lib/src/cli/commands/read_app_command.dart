import 'dart:convert';
import 'dart:io';

import 'package:flutter_cockpit_protocol/flutter_cockpit_protocol.dart';

import '../../application/cockpit_interactive_result_profile.dart';
import '../../application/cockpit_read_app_service.dart';
import '../cockpit_cli_help.dart';
import '../cockpit_command_runner.dart';
import '../cockpit_interactive_cli_support.dart';

typedef CockpitReadAppFunction =
    Future<CockpitReadAppResult> Function(CockpitReadAppRequest request);

final class ReadAppCommand extends CockpitCliCommand {
  ReadAppCommand({
    CockpitReadAppService? service,
    CockpitReadAppFunction? read,
    StringSink? stdoutSink,
  }) : _read = read ?? (service ?? CockpitReadAppService()).read,
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
      'cockpit read-app --app-json /tmp/app.json --profile minimal --stdout-format json | jq \'{currentRouteName,state}\'';

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
    final resultProfile = cockpitReadResultProfile(
      argResults,
      defaultProfile: CockpitInteractiveResultProfileName.minimal,
    );
    final result = await _read(
      CockpitReadAppRequest(
        baseUri: cockpitReadOptionalBaseUri(argResults),
        appHandlePath: cockpitResolveAppHandlePath(argResults),
        androidDeviceId: argResults?['android-device-id'] as String?,
        resultProfile: resultProfile,
        snapshotOptions: snapshotOptionsJson == null
            ? null
            : CockpitSnapshotOptions.fromJson(snapshotOptionsJson),
      ),
    );
    final payload =
        resultProfile.name == CockpitInteractiveResultProfileName.minimal
        ? cockpitCompactMinimalReadAppPayload(result.toJson())
        : result.toJson();
    await cockpitWriteJsonPayload(
      payload: const JsonEncoder.withIndent('  ').convert(payload),
      argResults: argResults,
      stdoutSink: _stdoutSink,
    );
    return cockpitSuccessExitCode;
  }
}
