import 'dart:io';
import 'dart:convert';

import 'package:args/command_runner.dart';
import 'package:flutter_cockpit/flutter_cockpit.dart';

import '../../application/cockpit_read_remote_snapshot_service.dart';
import '../cockpit_command_runner.dart';
import '../cockpit_interactive_cli_support.dart';

typedef CockpitReadRemoteSnapshotFunction
    = Future<CockpitReadRemoteSnapshotResult> Function(
  CockpitReadRemoteSnapshotRequest request,
);

final class ReadRemoteSnapshotCommand extends Command<int> {
  ReadRemoteSnapshotCommand({
    CockpitReadRemoteSnapshotService? service,
    CockpitReadRemoteSnapshotFunction? read,
    StringSink? stdoutSink,
  })  : _read = read ?? (service ?? CockpitReadRemoteSnapshotService()).read,
        _stdoutSink = stdoutSink ?? stdout {
    cockpitAddRemoteSessionArgs(argParser);
    cockpitAddProfileArg(argParser);
    argParser
      ..addOption('snapshot-options-json')
      ..addOption('snapshot-options-file')
      ..addOption('compare-against-snapshot-ref');
  }

  final CockpitReadRemoteSnapshotFunction _read;
  final StringSink _stdoutSink;

  @override
  String get name => 'read-remote-snapshot';

  @override
  String get description =>
      'Read a remote flutter_cockpit snapshot with layered interactive output.';

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
        sessionHandlePath: argResults?['session-json'] as String?,
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
}
