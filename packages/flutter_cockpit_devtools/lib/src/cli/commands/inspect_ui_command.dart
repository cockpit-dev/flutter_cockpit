import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:flutter_cockpit/flutter_cockpit.dart';

import '../../application/cockpit_inspect_ui_service.dart';
import '../cockpit_command_runner.dart';
import '../../application/cockpit_json_key_normalizer.dart';
import '../cockpit_interactive_cli_support.dart';

typedef CockpitInspectUiFunction = Future<CockpitInspectUiResult> Function(
  CockpitInspectUiRequest request,
);

final class InspectUiCommand extends Command<int> {
  InspectUiCommand({
    CockpitInspectUiService? service,
    CockpitInspectUiFunction? inspect,
    StringSink? stdoutSink,
  })  : _inspect = inspect ?? (service ?? CockpitInspectUiService()).inspect,
        _stdoutSink = stdoutSink ?? stdout {
    cockpitAddAppArgs(argParser);
    cockpitAddProfileArg(argParser);
    argParser
      ..addOption('snapshot-options-json')
      ..addOption('snapshot-options-file')
      ..addOption('compare-against-snapshot-ref');
  }

  final CockpitInspectUiFunction _inspect;
  final StringSink _stdoutSink;

  @override
  String get name => 'inspect-ui';

  @override
  String get description =>
      'Inspect the current UI tree with summary, diagnostics, delta, and snapshot layers.';

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
    final result = await _inspect(
      CockpitInspectUiRequest(
        baseUri: cockpitReadOptionalBaseUri(argResults),
        appHandlePath: argResults?['app-json'] as String?,
        androidDeviceId: argResults?['android-device-id'] as String?,
        resultProfile: cockpitReadResultProfile(argResults),
        snapshotOptions: snapshotOptionsJson == null
            ? null
            : CockpitSnapshotOptions.fromJson(
                cockpitNormalizeJsonKeys(snapshotOptionsJson),
              ),
        compareAgainstSnapshotRef:
            argResults?['compare-against-snapshot-ref'] as String?,
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
