import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:flutter_cockpit/flutter_cockpit.dart';

import '../../application/cockpit_collect_remote_snapshot_service.dart';
import '../../application/cockpit_compact_json.dart';
import '../cockpit_command_runner.dart';

typedef CockpitCollectRemoteSnapshotFunction
    = Future<CockpitCollectRemoteSnapshotResult> Function(
  CockpitCollectRemoteSnapshotRequest request,
);

final class CollectRemoteSnapshotCommand extends Command<int> {
  CollectRemoteSnapshotCommand({
    CockpitCollectRemoteSnapshotService? service,
    CockpitCollectRemoteSnapshotFunction? collect,
    StringSink? stdoutSink,
  })  : _collect = collect ??
            (service ?? CockpitCollectRemoteSnapshotService()).collect,
        _stdoutSink = stdoutSink ?? stdout {
    argParser
      ..addOption('base-url', help: 'Base URL for the running app session.')
      ..addOption(
        'session-json',
        help:
            'Optional session handle JSON file emitted by launch-remote-session.',
      )
      ..addOption(
        'output-json',
        help:
            'Optional file path where the snapshot payload should be written.',
      )
      ..addOption(
        'android-device-id',
        help: 'Optional Android device ID used to set up adb port forwarding.',
      )
      ..addOption(
        'profile',
        help: 'Snapshot detail profile.',
        allowed: CockpitSnapshotProfile.values
            .map((value) => value.jsonValue)
            .toList(growable: false),
        defaultsTo: CockpitSnapshotProfile.live.jsonValue,
      )
      ..addOption('max-targets')
      ..addOption('max-ancestors-per-target')
      ..addOption('max-properties-per-target')
      ..addOption('max-accessibility-entries')
      ..addFlag(
        'include-style-details',
        negatable: false,
        help: 'Include richer style details for visible targets.',
      )
      ..addFlag(
        'include-diagnostic-properties',
        negatable: false,
        help: 'Include diagnostics properties for visible targets.',
      )
      ..addFlag(
        'include-accessibility-summary',
        negatable: false,
        help:
            'Include a bounded accessibility traversal summary for visible semantics targets.',
      )
      ..addFlag(
        'emit-artifact-when-large',
        negatable: false,
        help:
            'Request artifact externalization when diagnostics grow large so remote sessions can stream full forensic snapshots through downloadable artifacts.',
      )
      ..addFlag(
        'include-network-activity',
        negatable: false,
        help: 'Include captured HTTP activity in the snapshot.',
      )
      ..addFlag(
        'include-runtime-activity',
        negatable: false,
        help: 'Include captured Flutter runtime errors and logs.',
      )
      ..addOption('max-network-entries')
      ..addOption('max-runtime-entries')
      ..addOption('network-method')
      ..addOption('network-uri-contains')
      ..addOption('runtime-message-contains')
      ..addFlag(
        'network-only-failures',
        defaultsTo: null,
        help: 'Only include failed HTTP requests in the snapshot network view.',
      )
      ..addFlag(
        'runtime-only-errors',
        defaultsTo: null,
        help:
            'Only include runtime entries classified as errors in the snapshot runtime view.',
      )
      ..addOption('network-status-code-at-least');
  }

  final CockpitCollectRemoteSnapshotFunction _collect;
  final StringSink _stdoutSink;

  @override
  String get name => 'collect-remote-snapshot';

  @override
  String get description =>
      'Collect a remote flutter_cockpit snapshot with optional rich diagnostics and network activity.';

  @override
  Future<int> run() async {
    final sessionJsonPath = argResults?['session-json'] as String?;
    final baseUrl = argResults?['base-url'] as String?;
    if ((sessionJsonPath == null || sessionJsonPath.isEmpty) &&
        (baseUrl == null || baseUrl.isEmpty)) {
      throw UsageException(
        '--base-url is required when --session-json is not provided.',
        usage,
      );
    }

    final result = await _collect(
      CockpitCollectRemoteSnapshotRequest(
        baseUri: baseUrl == null || baseUrl.isEmpty ? null : Uri.parse(baseUrl),
        sessionHandlePath: sessionJsonPath,
        androidDeviceId: argResults?['android-device-id'] as String?,
        options: _readSnapshotOptions(),
      ),
    );
    final payload = cockpitPrettyJsonText(result.toJson());
    final outputJson = argResults?['output-json'] as String?;

    if (outputJson == null || outputJson.isEmpty) {
      _stdoutSink.writeln(payload);
    } else {
      final outputFile = File(outputJson);
      await outputFile.parent.create(recursive: true);
      await outputFile.writeAsString(payload);
    }
    return cockpitSuccessExitCode;
  }

  CockpitSnapshotOptions _readSnapshotOptions() {
    final profile = CockpitSnapshotProfile.fromJson(argResults?['profile']);
    var options = switch (profile) {
      CockpitSnapshotProfile.live => const CockpitSnapshotOptions.live(),
      CockpitSnapshotProfile.baseline =>
        const CockpitSnapshotOptions.baseline(),
      CockpitSnapshotProfile.investigate =>
        const CockpitSnapshotOptions.investigate(),
      CockpitSnapshotProfile.forensic =>
        const CockpitSnapshotOptions.forensic(),
    };

    final networkQuery = CockpitNetworkQuery(
      method: _readOptionalString('network-method'),
      uriContains: _readOptionalString('network-uri-contains'),
      onlyFailures: _readOptionalFlag('network-only-failures') ??
          options.networkQuery.onlyFailures,
      statusCodeAtLeast: _readOptionalInt('network-status-code-at-least'),
    );
    final runtimeQuery = CockpitRuntimeQuery(
      onlyErrors: _readOptionalFlag('runtime-only-errors') ??
          options.runtimeQuery.onlyErrors,
      messageContains: _readOptionalString('runtime-message-contains'),
    );
    final includeNetworkActivity =
        _readFlag('include-network-activity') || !networkQuery.isEmpty
            ? true
            : options.includeNetworkActivity;
    final includeRuntimeActivity =
        _readFlag('include-runtime-activity') || !runtimeQuery.isEmpty
            ? true
            : options.includeRuntimeActivity;

    return options.copyWith(
      maxTargets: _readOptionalInt('max-targets') ?? options.maxTargets,
      maxAncestorsPerTarget: _readOptionalInt('max-ancestors-per-target') ??
          options.maxAncestorsPerTarget,
      maxPropertiesPerTarget: _readOptionalInt('max-properties-per-target') ??
          options.maxPropertiesPerTarget,
      maxAccessibilityEntries: _readOptionalInt('max-accessibility-entries') ??
          options.maxAccessibilityEntries,
      includeStyleDetails:
          _readFlag('include-style-details') || options.includeStyleDetails,
      includeDiagnosticProperties: _readFlag('include-diagnostic-properties') ||
          options.includeDiagnosticProperties,
      includeAccessibilitySummary: _readFlag('include-accessibility-summary') ||
          options.includeAccessibilitySummary,
      emitArtifactWhenLarge: _readFlag('emit-artifact-when-large') ||
          options.emitArtifactWhenLarge,
      includeNetworkActivity: includeNetworkActivity,
      maxNetworkEntries:
          _readOptionalInt('max-network-entries') ?? options.maxNetworkEntries,
      networkQuery: networkQuery,
      includeRuntimeActivity: includeRuntimeActivity,
      maxRuntimeEntries:
          _readOptionalInt('max-runtime-entries') ?? options.maxRuntimeEntries,
      runtimeQuery: runtimeQuery,
    );
  }

  int? _readOptionalInt(String name) {
    final value = argResults?[name] as String?;
    if (value == null || value.isEmpty) {
      return null;
    }
    return int.parse(value);
  }

  String? _readOptionalString(String name) {
    final value = argResults?[name] as String?;
    if (value == null || value.isEmpty) {
      return null;
    }
    return value;
  }

  bool _readFlag(String name) => argResults?[name] as bool? ?? false;

  bool? _readOptionalFlag(String name) {
    if (!(argResults?.wasParsed(name) ?? false)) {
      return null;
    }
    return argResults?[name] as bool?;
  }
}
