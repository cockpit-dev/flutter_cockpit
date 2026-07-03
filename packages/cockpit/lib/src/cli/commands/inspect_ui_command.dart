import 'dart:convert';
import 'dart:io';

import 'package:flutter_cockpit_protocol/flutter_cockpit_protocol.dart';

import '../../application/cockpit_inspect_ui_service.dart';
import '../cockpit_cli_help.dart';
import '../cockpit_command_runner.dart';
import '../cockpit_interactive_cli_support.dart';

typedef CockpitInspectUiFunction =
    Future<CockpitInspectUiResult> Function(CockpitInspectUiRequest request);

final class InspectUiCommand extends CockpitCliCommand {
  InspectUiCommand({
    CockpitInspectUiService? service,
    CockpitInspectUiFunction? inspect,
    StringSink? stdoutSink,
  }) : _inspect = inspect ?? (service ?? CockpitInspectUiService()).inspect,
       _stdoutSink = stdoutSink ?? stdout {
    cockpitAddAppArgs(argParser);
    cockpitAddProfileArg(argParser);
    cockpitAddSnapshotOptionsArgs(argParser);
    cockpitAddCompareAgainstSnapshotRefArg(argParser);
  }

  final CockpitInspectUiFunction _inspect;
  final StringSink _stdoutSink;

  @override
  String get name => 'inspect-ui';

  @override
  String get description =>
      'Inspect the current UI tree with richer layering than read-app.';

  @override
  String get summary => 'Read richer UI tree and deltas.';

  @override
  String get category => CockpitCliCategory.coreLoop;

  @override
  String get helpWhen =>
      'Escalate from read-app when you need target summaries, diagnostics, or diffs.';

  @override
  String get helpNeeds =>
      'An app reference and usually --profile inspect or evidence when minimal status is no longer enough.';

  @override
  String get helpExample =>
      'cockpit inspect-ui --app-json /tmp/app.json --profile inspect';

  @override
  String get helpWrites =>
      'Layered JSON with UI summaries, optional diagnostics, delta, and snapshotRef.';

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
        appHandlePath: cockpitResolveAppHandlePath(argResults),
        androidDeviceId: argResults?['android-device-id'] as String?,
        resultProfile: cockpitReadResultProfile(argResults),
        snapshotOptions: snapshotOptionsJson == null
            ? null
            : cockpitDecodeCliJson(
                decode: () =>
                    CockpitSnapshotOptions.fromJson(snapshotOptionsJson),
                label: 'snapshot options JSON',
                usage: usage,
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
