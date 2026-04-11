import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:flutter_cockpit/flutter_cockpit.dart';

import '../../application/cockpit_inspect_surface_service.dart';
import '../cockpit_cli_help.dart';
import '../cockpit_command_runner.dart';
import '../cockpit_interactive_cli_support.dart';

typedef CockpitInspectSurfaceCliFunction = Future<CockpitInspectSurfaceResult>
    Function(
  CockpitInspectSurfaceRequest request,
);

final class InspectSurfaceCommand extends CockpitCliCommand {
  InspectSurfaceCommand({
    CockpitInspectSurfaceService? service,
    CockpitInspectSurfaceCliFunction? inspect,
    StringSink? stdoutSink,
  })  : _inspect =
            inspect ?? (service ?? CockpitInspectSurfaceService()).inspect,
        _stdoutSink = stdoutSink ?? stdout {
    cockpitAddAppArgs(argParser);
    argParser.addOption('target-json');
    cockpitAddProfileArg(argParser);
    cockpitAddSnapshotOptionsArgs(argParser);
    cockpitAddCompareAgainstSnapshotRefArg(argParser);
  }

  final CockpitInspectSurfaceCliFunction _inspect;
  final StringSink _stdoutSink;

  @override
  String get name => 'inspect-surface';

  @override
  String get description =>
      'Inspect the current target surface with richer layering than read-target.';

  @override
  String get summary => 'Read richer target surface and deltas.';

  @override
  String get category => CockpitCliCategory.coreLoop;

  @override
  Future<int> run() async {
    _requireTargetReference();
    final snapshotOptionsJson = await cockpitReadOptionalJsonObject(
      argResults: argResults,
      inlineOption: 'snapshot-options-json',
      fileOption: 'snapshot-options-file',
      label: 'snapshot options JSON',
      usage: usage,
    );
    final result = await _inspect(
      CockpitInspectSurfaceRequest(
        targetHandlePath: argResults?['target-json'] as String?,
        appHandlePath: argResults?['app-json'] as String?,
        baseUri: cockpitReadOptionalBaseUri(argResults),
        androidDeviceId: argResults?['android-device-id'] as String?,
        resultProfile: cockpitReadResultProfile(argResults),
        snapshotOptions: snapshotOptionsJson == null
            ? null
            : CockpitSnapshotOptions.fromJson(snapshotOptionsJson),
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

  void _requireTargetReference() {
    final targetJsonPath = argResults?['target-json'] as String?;
    final appJsonPath = argResults?['app-json'] as String?;
    final baseUrl = argResults?['base-url'] as String?;
    if ((targetJsonPath == null || targetJsonPath.isEmpty) &&
        (appJsonPath == null || appJsonPath.isEmpty) &&
        (baseUrl == null || baseUrl.isEmpty)) {
      throw UsageException(
        '--target-json, --app-json, or --base-url is required.',
        usage,
      );
    }
  }
}
