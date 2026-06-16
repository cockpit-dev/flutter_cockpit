import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:flutter_cockpit/flutter_cockpit.dart';

import '../../application/cockpit_read_target_service.dart';
import '../../application/cockpit_interactive_result_profile.dart';
import '../cockpit_cli_help.dart';
import '../cockpit_command_runner.dart';
import '../cockpit_interactive_cli_support.dart';

typedef CockpitReadTargetCliFunction =
    Future<CockpitReadTargetResult> Function(CockpitReadTargetRequest request);

final class ReadTargetCommand extends CockpitCliCommand {
  ReadTargetCommand({
    CockpitReadTargetService? service,
    CockpitReadTargetCliFunction? read,
    StringSink? stdoutSink,
  }) : _read = read ?? (service ?? CockpitReadTargetService()).read,
       _stdoutSink = stdoutSink ?? stdout {
    cockpitAddAppArgs(argParser);
    argParser.addOption('target-json', help: cockpitTargetJsonOptionHelp);
    cockpitAddProfileArg(
      argParser,
      defaultProfile: CockpitInteractiveResultProfileName.minimal,
    );
    cockpitAddSnapshotOptionsArgs(argParser);
  }

  final CockpitReadTargetCliFunction _read;
  final StringSink _stdoutSink;

  @override
  String get name => 'read-target';

  @override
  String get description =>
      'Read current target state with the smallest useful result profile.';

  @override
  String get summary => 'Read target state and small UI summary.';

  @override
  String get category => CockpitCliCategory.coreLoop;

  @override
  String get helpWhen =>
      'Use when the current surface is target-first and you need the smallest truthful target, plane, and capability summary before acting.';

  @override
  String get helpNeeds =>
      'A target reference from --target-json, the default latest target handle, --app-json, or --base-url. Prefer --profile minimal for routine polling.';

  @override
  String get helpExample => 'cockpit read-target';

  @override
  String get helpWrites =>
      'Layered JSON with normalized target metadata, selected plane, capability profile, and optional bounded UI summary.';

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
    final result = await _read(
      CockpitReadTargetRequest(
        targetHandlePath: cockpitResolveTargetHandlePath(argResults),
        appHandlePath: cockpitResolveAppHandlePath(argResults),
        baseUri: cockpitReadOptionalBaseUri(argResults),
        androidDeviceId: argResults?['android-device-id'] as String?,
        resultProfile: cockpitReadResultProfile(
          argResults,
          defaultProfile: CockpitInteractiveResultProfileName.minimal,
        ),
        snapshotOptions: snapshotOptionsJson == null
            ? null
            : cockpitDecodeCliJson(
                decode: () =>
                    CockpitSnapshotOptions.fromJson(snapshotOptionsJson),
                label: 'snapshot options JSON',
                usage: usage,
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

  void _requireTargetReference() {
    final targetJsonPath = cockpitResolveTargetHandlePath(argResults);
    final appJsonPath = cockpitResolveAppHandlePath(argResults);
    final baseUrl = argResults?['base-url'] as String?;
    if ((targetJsonPath == null || targetJsonPath.isEmpty) &&
        (appJsonPath == null || appJsonPath.isEmpty) &&
        (baseUrl == null || baseUrl.isEmpty)) {
      throw UsageException(
        '--target-json, --app-json, or --base-url is required unless '
        '${cockpitDefaultTargetHandlePath()} or ${cockpitDefaultAppHandlePath()} exists.',
        usage,
      );
    }
  }
}
