import 'package:flutter_cockpit/flutter_cockpit.dart';

import '../remote/cockpit_remote_session_client.dart';
import 'cockpit_app_reference_resolver.dart';
import 'cockpit_json_key_normalizer.dart';
import 'cockpit_latest_task_store.dart';
import 'cockpit_session_registry.dart';

final class CockpitRuntimeErrorEntry {
  const CockpitRuntimeErrorEntry({
    required this.source,
    required this.message,
    this.recordedAt,
    this.sessionId,
    this.bundleDir,
    this.kind,
    this.routeName,
  });

  final String source;
  final String message;
  final DateTime? recordedAt;
  final String? sessionId;
  final String? bundleDir;
  final String? kind;
  final String? routeName;

  Map<String, Object?> toJson() => <String, Object?>{
        'source': source,
        'message': message,
        'recorded_at': recordedAt?.toUtc().toIso8601String(),
        'session_id': sessionId,
        'bundle_dir': bundleDir,
        'kind': kind == null ? null : cockpitSnakeCaseEnumValue('kind', kind!),
        'route_name': routeName,
      };
}

final class CockpitReadRuntimeErrorsRequest {
  const CockpitReadRuntimeErrorsRequest({
    this.appId,
    this.appHandlePath,
    this.baseUri,
    this.androidDeviceId,
    this.maxErrors = 20,
    this.includeLatestTask,
    this.includeSessions,
  });

  final String? appId;
  final String? appHandlePath;
  final Uri? baseUri;
  final String? androidDeviceId;
  final int maxErrors;
  final bool? includeLatestTask;
  final bool? includeSessions;

  bool get hasAppReference =>
      (appId != null && appId!.isNotEmpty) ||
      (appHandlePath != null && appHandlePath!.isNotEmpty) ||
      baseUri != null;

  bool get effectiveIncludeLatestTask => includeLatestTask ?? !hasAppReference;

  bool get effectiveIncludeSessions => includeSessions ?? !hasAppReference;
}

final class CockpitReadRuntimeErrorsResult {
  const CockpitReadRuntimeErrorsResult({
    required this.errors,
    this.appId,
    this.routeName,
    this.source,
  });

  final List<CockpitRuntimeErrorEntry> errors;
  final String? appId;
  final String? routeName;
  final String? source;

  bool get hasErrors => errors.isNotEmpty;

  Map<String, Object?> toJson() => <String, Object?>{
        'app_id': appId,
        'route_name': routeName,
        'source': source,
        'has_errors': hasErrors,
        'errors': errors.map((error) => error.toJson()).toList(growable: false),
      };
}

final class CockpitReadRuntimeErrorsService {
  CockpitReadRuntimeErrorsService({
    required CockpitSessionRegistry registry,
    required CockpitLatestTaskStore latestTaskStore,
    CockpitAppReferenceResolver? appReferenceResolver,
    CockpitReadRuntimeErrorsSnapshotReader? readSnapshot,
  })  : _registry = registry,
        _latestTaskStore = latestTaskStore,
        _appReferenceResolver = appReferenceResolver ??
            CockpitAppReferenceResolver(registry: registry),
        _readSnapshot = readSnapshot ??
            ((baseUri, options) => CockpitRemoteSessionClient(
                  baseUri: baseUri,
                ).readSnapshotDetailed(options: options));

  final CockpitSessionRegistry _registry;
  final CockpitLatestTaskStore _latestTaskStore;
  final CockpitAppReferenceResolver _appReferenceResolver;
  final CockpitReadRuntimeErrorsSnapshotReader _readSnapshot;

  Future<CockpitReadRuntimeErrorsResult> read(
    CockpitReadRuntimeErrorsRequest request,
  ) async {
    final errors = <CockpitRuntimeErrorEntry>[];
    String? appId;
    String? routeName;
    String? source;
    if (request.hasAppReference) {
      final resolved = await _appReferenceResolver.resolve(
        appId: request.appId,
        appHandlePath: request.appHandlePath,
        baseUri: request.baseUri,
        androidDeviceId: request.androidDeviceId,
      );
      appId = resolved.app?.appId ?? request.appId;
      source = 'app_snapshot';
      final snapshot = (await _readSnapshot(
        resolved.baseUri,
        CockpitSnapshotOptions(
          profile: CockpitSnapshotProfile.investigate,
          includeRuntimeActivity: true,
          maxRuntimeEntries: request.maxErrors <= 0 ? 20 : request.maxErrors,
          runtimeQuery: const CockpitRuntimeQuery(onlyErrors: true),
        ),
      ))
          .snapshot;
      routeName = snapshot.routeName;
      final runtime = snapshot.runtime;
      if (runtime != null) {
        for (final event in runtime.entries) {
          errors.add(
            CockpitRuntimeErrorEntry(
              source: 'app_snapshot',
              message: event.message,
              recordedAt: event.recordedAt,
              kind: event.kind.jsonValue,
              routeName: event.routeName ?? snapshot.routeName,
            ),
          );
        }
      }
    }
    if (request.effectiveIncludeSessions) {
      final snapshot = _registry.snapshot();
      for (final record in snapshot.developmentSessions) {
        final lastError = record.status.lastError;
        if (lastError == null || lastError.isEmpty) {
          continue;
        }
        errors.add(
          CockpitRuntimeErrorEntry(
            source: 'development_session',
            message: lastError,
            recordedAt: record.updatedAt,
            sessionId: record.handle.developmentSessionId,
          ),
        );
      }
    }
    if (request.effectiveIncludeLatestTask) {
      final latest = _latestTaskStore.latest;
      final runtimeErrors =
          latest?.bundleSummary?.runtimeSummary?.errorEntries ?? const [];
      for (final event in runtimeErrors) {
        errors.add(
          CockpitRuntimeErrorEntry(
            source: 'latest_task_bundle',
            message: event.message,
            recordedAt: event.recordedAt,
            bundleDir: latest?.bundleSummary?.bundleDir,
            kind: event.kind.jsonValue,
            routeName: event.routeName,
          ),
        );
      }
    }
    errors.sort((left, right) {
      final leftAt = left.recordedAt;
      final rightAt = right.recordedAt;
      if (leftAt == null && rightAt == null) {
        return 0;
      }
      if (leftAt == null) {
        return 1;
      }
      if (rightAt == null) {
        return -1;
      }
      return rightAt.compareTo(leftAt);
    });
    return CockpitReadRuntimeErrorsResult(
      appId: appId,
      routeName: routeName,
      source: request.hasAppReference
          ? (request.effectiveIncludeSessions ||
                  request.effectiveIncludeLatestTask
              ? 'mixed'
              : source)
          : (request.effectiveIncludeSessions ||
                  request.effectiveIncludeLatestTask
              ? 'aggregate'
              : null),
      errors: List<CockpitRuntimeErrorEntry>.unmodifiable(errors),
    );
  }
}

typedef CockpitReadRuntimeErrorsSnapshotReader
    = Future<CockpitRemoteSnapshotResponse> Function(
  Uri baseUri,
  CockpitSnapshotOptions options,
);
