import 'dart:io';
import 'dart:convert';

import 'package:cockpit_protocol/cockpit_protocol.dart';

import '../../application/cockpit_read_remote_snapshot_service.dart';
import '../cockpit_cli_help.dart';
import '../cockpit_command_runner.dart';
import '../cockpit_interactive_cli_support.dart';

typedef CockpitReadRemoteSnapshotFunction =
    Future<CockpitReadRemoteSnapshotResult> Function(
      CockpitReadRemoteSnapshotRequest request,
    );

final class ReadRemoteSnapshotCommand extends CockpitCliCommand {
  ReadRemoteSnapshotCommand({
    CockpitReadRemoteSnapshotService? service,
    CockpitReadRemoteSnapshotFunction? read,
    StringSink? stdoutSink,
  }) : _read = read ?? (service ?? CockpitReadRemoteSnapshotService()).read,
       _stdoutSink = stdoutSink ?? stdout {
    cockpitAddRemoteSessionArgs(argParser);
    cockpitAddProfileArg(argParser);
    argParser
      ..addOption(
        'snapshot-options-json',
        help:
            'Inline JSON that overrides snapshot detail and collection limits.',
      )
      ..addOption(
        'snapshot-options-file',
        help: 'Path to snapshot options JSON.',
      )
      ..addOption(
        'compare-against-snapshot-ref',
        help: 'Existing snapshot ref used to compute a bounded delta.',
      );
  }

  final CockpitReadRemoteSnapshotFunction _read;
  final StringSink _stdoutSink;

  @override
  String get name => 'read-remote-snapshot';

  @override
  String get description =>
      'Read a remote flutter_cockpit snapshot with layered interactive output.';

  @override
  String get summary => 'Read remote snapshot.';

  @override
  String get category => CockpitCliCategory.coreLoop;

  @override
  String get helpWhen =>
      'Escalate from read-remote-status when the current UI structure or delta is needed.';

  @override
  String get helpNeeds =>
      'Either --session-json or --base-url, plus optional snapshot controls.';

  @override
  String get helpExample =>
      'cockpit read-remote-snapshot --session-json /tmp/session.json --profile standard';

  @override
  String get helpWrites =>
      'A layered remote snapshot result; use artifactDownloads metadata before fetching large diagnostics.';

  @override
  Future<int> run() async {
    cockpitRequireRemoteSessionReference(argResults, usage);
    final snapshotOptionsJson = await cockpitReadOptionalJsonObject(
      argResults: argResults,
      inlineOption: 'snapshot-options-json',
      fileOption: 'snapshot-options-file',
      label: 'snapshot options JSON',
      usage: usage,
    );
    final result = await _read(
      CockpitReadRemoteSnapshotRequest(
        baseUri: cockpitReadOptionalBaseUri(argResults),
        sessionHandlePath: cockpitResolveRemoteSessionHandlePath(argResults),
        androidDeviceId: argResults?['android-device-id'] as String?,
        iosDeviceId: argResults?['ios-device-id'] as String?,
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
}
