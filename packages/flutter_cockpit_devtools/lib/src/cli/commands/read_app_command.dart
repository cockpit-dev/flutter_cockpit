import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:flutter_cockpit/flutter_cockpit.dart';

import '../../application/cockpit_interactive_result_profile.dart';
import '../../application/cockpit_json_key_normalizer.dart';
import '../../application/cockpit_read_app_service.dart';
import '../cockpit_command_runner.dart';
import '../cockpit_interactive_cli_support.dart';

typedef CockpitReadAppFunction = Future<CockpitReadAppResult> Function(
  CockpitReadAppRequest request,
);

final class ReadAppCommand extends Command<int> {
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
    argParser
      ..addOption('snapshot-options-json')
      ..addOption('snapshot-options-file');
  }

  final CockpitReadAppFunction _read;
  final StringSink _stdoutSink;

  @override
  String get name => 'read-app';

  @override
  String get description =>
      'Read lightweight app status with optional richer UI layering.';

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
            : CockpitSnapshotOptions.fromJson(
                cockpitNormalizeJsonKeys(snapshotOptionsJson),
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
