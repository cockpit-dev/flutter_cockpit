import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:flutter_cockpit/flutter_cockpit.dart';

import '../../application/cockpit_collect_remote_snapshot_service.dart';
import '../cockpit_cli_help.dart';
import '../cockpit_command_runner.dart';
import '../cockpit_interactive_cli_support.dart';

typedef CockpitCollectRemoteSnapshotFunction
    = Future<CockpitCollectRemoteSnapshotResult> Function(
  CockpitCollectRemoteSnapshotRequest request,
);

final class CollectRemoteSnapshotCommand extends CockpitCliCommand {
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
        help: cockpitRemoteSessionJsonOptionHelp,
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
      ..addOption('max-targets', help: 'Maximum visible targets to collect.')
      ..addOption(
        'max-ancestors-per-target',
        help: 'Maximum ancestor chain length per target.',
      )
      ..addOption(
        'max-properties-per-target',
        help: 'Maximum diagnostic properties per target.',
      )
      ..addOption(
        'max-accessibility-entries',
        help: 'Maximum accessibility summary entries.',
      )
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
        'download-diagnostics-artifacts',
        negatable: false,
        help:
            'Download externalized diagnostics artifacts into the output payload. Leave off for summary-first, token-efficient reads.',
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
      ..addOption(
        'max-network-entries',
        help: 'Maximum captured network entries to include.',
      )
      ..addOption(
        'max-runtime-entries',
        help: 'Maximum runtime entries to include.',
      )
      ..addOption('network-method', help: 'Filter network entries by method.')
      ..addOption(
        'network-uri-contains',
        help: 'Filter network entries by URI substring.',
      )
      ..addOption(
        'runtime-message-contains',
        help: 'Filter runtime entries by message substring.',
      )
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
      ..addOption(
        'network-status-code-at-least',
        help:
            'Filter network entries to HTTP status codes at or above this value.',
      );
  }

  final CockpitCollectRemoteSnapshotFunction _collect;
  final StringSink _stdoutSink;

  @override
  String get name => 'collect-remote-snapshot';

  @override
  String get description =>
      'Collect a remote flutter_cockpit snapshot with optional rich diagnostics and network activity.';

  @override
  String get summary => 'Collect remote diagnostics.';

  @override
  String get category => CockpitCliCategory.coreLoop;

  @override
  String get helpWhen =>
      'Use only when a layered read still lacks the diagnostic details needed for repair.';

  @override
  String get helpNeeds =>
      'Either --session-json, the default latest remote session handle, or --base-url plus explicit bounds for any expanded collections.';

  @override
  String get helpExample =>
      'flutter_cockpit_devtools collect-remote-snapshot --profile forensic --emit-artifact-when-large';

  @override
  String get helpWrites =>
      'A snapshot payload with effective options, warnings, and artifact download metadata for large diagnostics.';

  @override
  Future<int> run() async {
    final sessionJsonPath = cockpitResolveRemoteSessionHandlePath(argResults);
    final baseUrl = argResults?['base-url'] as String?;
    if ((sessionJsonPath == null || sessionJsonPath.isEmpty) &&
        (baseUrl == null || baseUrl.isEmpty)) {
      throw UsageException(
        '--base-url is required when --session-json is not provided and '
        '${cockpitDefaultRemoteSessionHandlePath()} does not exist.',
        usage,
      );
    }

    final result = await _collect(
      CockpitCollectRemoteSnapshotRequest(
        baseUri: baseUrl == null || baseUrl.isEmpty ? null : Uri.parse(baseUrl),
        sessionHandlePath: sessionJsonPath,
        androidDeviceId: argResults?['android-device-id'] as String?,
        options: _readSnapshotOptions(),
        downloadDiagnosticsArtifacts:
            _readFlag('download-diagnostics-artifacts'),
      ),
    );
    await cockpitWriteJsonPayload(
      payload: result.toJson(),
      argResults: argResults,
      stdoutSink: _stdoutSink,
    );
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
      statusCodeAtLeast: cockpitReadOptionalHttpStatusCode(
        argResults,
        'network-status-code-at-least',
        usage,
      ),
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
    final parsed = int.tryParse(value);
    if (parsed == null) {
      throw UsageException('--$name must be an integer.', usage);
    }
    if (parsed >= 0) {
      return parsed;
    }
    throw UsageException('--$name must be a non-negative integer.', usage);
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
