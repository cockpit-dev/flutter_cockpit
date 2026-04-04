import 'package:flutter_cockpit/flutter_cockpit.dart';

import '../../application/cockpit_collect_remote_snapshot_service.dart';
import '../cockpit_mcp_error.dart';
import '../cockpit_mcp_tool.dart';

typedef CockpitCollectRemoteSnapshotToolFunction
    = Future<CockpitCollectRemoteSnapshotResult> Function(
  CockpitCollectRemoteSnapshotRequest request,
);

final class CockpitCollectRemoteSnapshotTool extends CockpitMcpTool {
  CockpitCollectRemoteSnapshotTool({
    CockpitCollectRemoteSnapshotService? service,
    CockpitCollectRemoteSnapshotToolFunction? collect,
  }) : _collect = collect ??
            (service ?? CockpitCollectRemoteSnapshotService()).collect;

  final CockpitCollectRemoteSnapshotToolFunction _collect;

  @override
  String get name => 'collect_remote_snapshot';

  @override
  String get description =>
      'Collect a remote flutter_cockpit snapshot with explicit diagnostic and network detail controls.';

  @override
  Map<String, Object?> get inputSchema => const <String, Object?>{
        'type': 'object',
        'properties': <String, Object?>{
          'sessionHandle': <String, Object?>{'type': 'object'},
          'sessionHandlePath': <String, Object?>{'type': 'string'},
          'snapshotOptions': <String, Object?>{'type': 'object'},
        },
      };

  @override
  Future<Map<String, Object?>> call(Map<String, Object?> arguments) async {
    try {
      final snapshotOptionsJson = cockpitReadOptionalObject(
        arguments,
        'snapshot_options',
      );
      final result = await _collect(
        CockpitCollectRemoteSnapshotRequest(
          sessionHandle: cockpitReadOptionalSessionHandle(arguments),
          sessionHandlePath: cockpitReadOptionalString(
            arguments,
            'session_handle_path',
          ),
          options: snapshotOptionsJson == null
              ? const CockpitSnapshotOptions.live()
              : CockpitSnapshotOptions.fromJson(
                  _normalizeSnapshotOptions(snapshotOptionsJson),
                ),
        ),
      );

      return cockpitMcpResult(
        text: 'Remote snapshot collected.',
        structuredContent: <String, Object?>{
          'snapshot': result.snapshot.toJson(),
          'effectiveOptions': result.effectiveOptions.toJson(),
          'sessionHandle': result.sessionHandle?.toJson(),
          'warnings': result.warnings,
        },
      );
    } on Object catch (error) {
      cockpitRethrowAsMcpError(error);
    }
  }

  Map<String, Object?> _normalizeSnapshotOptions(Map<String, Object?> json) {
    final networkQuery = _readAliasedObject(
      json,
      'networkQuery',
      'network_query',
    );
    final runtimeQuery = _readAliasedObject(
      json,
      'runtimeQuery',
      'runtime_query',
    );
    return <String, Object?>{
      'profile': json['profile'],
      'maxTargets': _readAliasedValue(json, 'maxTargets', 'max_targets'),
      'maxAncestorsPerTarget': _readAliasedValue(
        json,
        'maxAncestorsPerTarget',
        'max_ancestors_per_target',
      ),
      'maxPropertiesPerTarget': _readAliasedValue(
        json,
        'maxPropertiesPerTarget',
        'max_properties_per_target',
      ),
      'includeStyleDetails': _readAliasedValue(
        json,
        'includeStyleDetails',
        'include_style_details',
      ),
      'includeDiagnosticProperties': _readAliasedValue(
        json,
        'includeDiagnosticProperties',
        'include_diagnostic_properties',
      ),
      'emitArtifactWhenLarge': _readAliasedValue(
        json,
        'emitArtifactWhenLarge',
        'emit_artifact_when_large',
      ),
      'includeNetworkActivity': _readAliasedValue(
        json,
        'includeNetworkActivity',
        'include_network_activity',
      ),
      'maxNetworkEntries': _readAliasedValue(
        json,
        'maxNetworkEntries',
        'max_network_entries',
      ),
      'includeRuntimeActivity': _readAliasedValue(
        json,
        'includeRuntimeActivity',
        'include_runtime_activity',
      ),
      'maxRuntimeEntries': _readAliasedValue(
        json,
        'maxRuntimeEntries',
        'max_runtime_entries',
      ),
      if (networkQuery != null)
        'networkQuery': <String, Object?>{
          'method': _readAliasedValue(networkQuery, 'method', 'method'),
          'uriContains': _readAliasedValue(
            networkQuery,
            'uriContains',
            'uri_contains',
          ),
          'onlyFailures': _readAliasedValue(
            networkQuery,
            'onlyFailures',
            'only_failures',
          ),
          'statusCodeAtLeast': _readAliasedValue(
            networkQuery,
            'statusCodeAtLeast',
            'status_code_at_least',
          ),
        },
      if (runtimeQuery != null)
        'runtimeQuery': <String, Object?>{
          'onlyErrors': _readAliasedValue(
            runtimeQuery,
            'onlyErrors',
            'only_errors',
          ),
          'messageContains': _readAliasedValue(
            runtimeQuery,
            'messageContains',
            'message_contains',
          ),
        },
    }..removeWhere((_, value) => value == null);
  }

  Object? _readAliasedValue(
    Map<String, Object?> json,
    String primaryKey,
    String fallbackKey,
  ) {
    return json.containsKey(primaryKey) ? json[primaryKey] : json[fallbackKey];
  }

  Map<String, Object?>? _readAliasedObject(
    Map<String, Object?> json,
    String primaryKey,
    String fallbackKey,
  ) {
    final value = _readAliasedValue(json, primaryKey, fallbackKey);
    if (value == null) {
      return null;
    }
    if (value is Map<Object?, Object?>) {
      return Map<String, Object?>.from(value);
    }
    throw CockpitMcpError.invalidArguments(
      'snapshot_options.networkQuery must be an object.',
    );
  }
}
