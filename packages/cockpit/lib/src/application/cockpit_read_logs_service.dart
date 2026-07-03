import 'package:flutter_cockpit_protocol/flutter_cockpit_protocol.dart';

import '../infrastructure/cockpit_file_system.dart';
import '../remote/cockpit_remote_session_client.dart';
import 'cockpit_app_reference_resolver.dart';
import 'cockpit_session_registry.dart';

typedef CockpitLogsSnapshotReader =
    Future<CockpitRemoteSnapshotResponse> Function(
      Uri baseUri,
      CockpitSnapshotOptions options,
    );

final class CockpitReadLogsRequest {
  const CockpitReadLogsRequest({
    this.appId,
    this.appHandlePath,
    this.baseUri,
    this.androidDeviceId,
    this.maxLines = 200,
  });

  final String? appId;
  final String? appHandlePath;
  final Uri? baseUri;
  final String? androidDeviceId;
  final int maxLines;
}

final class CockpitReadLogsResult {
  const CockpitReadLogsResult({
    required this.appId,
    required this.source,
    required this.available,
    required this.lines,
    required this.truncated,
    this.routeName,
    this.logPath,
    this.missingReason,
  });

  final String appId;
  final String source;
  final bool available;
  final String? routeName;
  final String? logPath;
  final List<String> lines;
  final bool truncated;
  final String? missingReason;

  Map<String, Object?> toJson() => <String, Object?>{
    'appId': appId,
    'source': source,
    'available': available,
    'routeName': routeName,
    'logPath': logPath,
    'lines': lines,
    'truncated': truncated,
    'missingReason': missingReason,
  };
}

final class CockpitReadLogsService {
  CockpitReadLogsService({
    required CockpitSessionRegistry registry,
    CockpitFileSystem? fileSystem,
    CockpitAppReferenceResolver? appReferenceResolver,
    CockpitLogsSnapshotReader? readSnapshot,
  }) : _fileSystem = fileSystem ?? const LocalCockpitFileSystem(),
       _appReferenceResolver =
           appReferenceResolver ??
           CockpitAppReferenceResolver(registry: registry),
       _readSnapshot =
           readSnapshot ??
           ((baseUri, options) => CockpitRemoteSessionClient(
             baseUri: baseUri,
           ).readSnapshotDetailed(options: options));

  final CockpitFileSystem _fileSystem;
  final CockpitAppReferenceResolver _appReferenceResolver;
  final CockpitLogsSnapshotReader _readSnapshot;

  Future<CockpitReadLogsResult> read(CockpitReadLogsRequest request) async {
    final safeMaxLines = request.maxLines <= 0 ? 200 : request.maxLines;
    final appId = request.appId;
    final resolved =
        (appId == null || appId.isEmpty) &&
            (request.appHandlePath == null || request.appHandlePath!.isEmpty) &&
            request.baseUri == null
        ? null
        : await _appReferenceResolver.resolve(
            appId: appId,
            appHandlePath: request.appHandlePath,
            baseUri: request.baseUri,
            androidDeviceId: request.androidDeviceId,
          );
    final effectiveAppId = resolved?.app?.appId ?? appId ?? 'unknown';
    final appSnapshotResult = await _readAppSnapshotLogs(
      baseUri: resolved?.baseUri,
      appId: effectiveAppId,
      maxLines: safeMaxLines,
    );
    if (appSnapshotResult != null) {
      return appSnapshotResult;
    }
    final logPath =
        resolved?.developmentRecord?.supervisorLogPath ??
        resolved?.app?.supervisorLogPath;
    if (logPath == null || logPath.isEmpty) {
      return CockpitReadLogsResult(
        appId: effectiveAppId,
        source: 'supervisor',
        available: false,
        logPath: null,
        lines: const <String>[],
        truncated: false,
        missingReason: 'log_unavailable',
      );
    }
    final file = _fileSystem.file(logPath);
    if (!file.existsSync()) {
      return CockpitReadLogsResult(
        appId: effectiveAppId,
        source: 'supervisor',
        available: false,
        logPath: logPath,
        lines: const <String>[],
        truncated: false,
        missingReason: 'log_file_missing',
      );
    }
    final lines = await file.readAsLines();
    final truncated = lines.length > safeMaxLines;
    final visibleLines = truncated
        ? lines.sublist(lines.length - safeMaxLines)
        : lines;
    return CockpitReadLogsResult(
      appId: effectiveAppId,
      source: 'supervisor',
      available: true,
      logPath: logPath,
      lines: List<String>.unmodifiable(visibleLines),
      truncated: truncated,
    );
  }

  Future<CockpitReadLogsResult?> _readAppSnapshotLogs({
    required Uri? baseUri,
    required String appId,
    required int maxLines,
  }) async {
    if (baseUri == null) {
      return null;
    }
    try {
      final snapshot = (await _readSnapshot(
        baseUri,
        CockpitSnapshotOptions(
          includeRuntimeActivity: true,
          maxRuntimeEntries: maxLines,
        ),
      )).snapshot;
      final runtime = snapshot.runtime;
      if (runtime == null) {
        return CockpitReadLogsResult(
          appId: appId,
          source: 'app_snapshot',
          available: true,
          routeName: snapshot.routeName,
          lines: const <String>[],
          truncated: false,
        );
      }
      return CockpitReadLogsResult(
        appId: appId,
        source: 'app_snapshot',
        available: true,
        routeName: snapshot.routeName,
        lines: List<String>.unmodifiable(
          runtime.entries.map(_formatRuntimeLogLine),
        ),
        truncated: runtime.truncated,
      );
    } on Object {
      return null;
    }
  }

  String _formatRuntimeLogLine(CockpitRuntimeEvent entry) {
    final parts = <String>[
      entry.severity.jsonValue,
      entry.kind.jsonValue,
      if (entry.source != null && entry.source!.isNotEmpty) entry.source!,
    ];
    return '${parts.join(' ')}: ${entry.message}';
  }
}
