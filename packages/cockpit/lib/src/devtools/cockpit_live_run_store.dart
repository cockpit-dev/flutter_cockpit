import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../infrastructure/cockpit_clock.dart';
import 'cockpit_live_run_event.dart';
import 'cockpit_live_run_state.dart';
import 'cockpit_sensitive_data_redactor.dart';

final class CockpitLiveRunPathException implements Exception {
  const CockpitLiveRunPathException(this.message);

  final String message;

  @override
  String toString() => 'CockpitLiveRunPathException: $message';
}

final class CockpitLiveRunStore {
  CockpitLiveRunStore({
    required String historyRoot,
    required this.runId,
    this.displayName,
    CockpitClock clock = const SystemCockpitClock(),
    CockpitSensitiveDataRedactor redactor =
        const CockpitSensitiveDataRedactor(),
    int recentEventLimit = 200,
    int recentArtifactLimit = 20,
    String? runDirectoryName,
  }) : _clock = clock,
       _redactor = redactor,
       _recentEventLimit = recentEventLimit,
       _recentArtifactLimit = recentArtifactLimit,
       historyRoot = p.normalize(p.absolute(historyRoot)),
       assert(recentEventLimit > 0, 'recentEventLimit must be positive'),
       assert(recentArtifactLimit > 0, 'recentArtifactLimit must be positive') {
    _runsRoot = p.join(this.historyRoot, 'runs');
    _runDirectory = Directory(
      p.join(
        _runsRoot,
        _safeDirectoryName(runDirectoryName ?? displayName ?? runId),
      ),
    );
    _liveDirectory = Directory(p.join(_runDirectory.path, 'live'));
  }

  final String historyRoot;
  final String runId;
  final String? displayName;
  final CockpitClock _clock;
  final CockpitSensitiveDataRedactor _redactor;
  final int _recentEventLimit;
  final int _recentArtifactLimit;
  final Queue<CockpitLiveRunEvent> _recentEvents = Queue<CockpitLiveRunEvent>();
  static final Map<String, Future<void>> _historyIndexWriteQueues =
      <String, Future<void>>{};

  late final String _runsRoot;
  late final Directory _runDirectory;
  late final Directory _liveDirectory;
  Future<void> _pendingWrite = Future<void>.value();
  CockpitLiveRunState? _state;
  var _lastSeq = 0;

  Directory get runDirectory => _runDirectory;

  Directory get liveDirectory => _liveDirectory;

  List<CockpitLiveRunEvent> get recentEvents =>
      List<CockpitLiveRunEvent>.unmodifiable(_recentEvents);

  CockpitLiveRunState? get state => _state;

  Future<void> initialize({
    String? workspaceId,
    String? scopeId,
    String? scopeKind,
    String? scopeLabel,
    String? sessionId,
    String? taskId,
    String? platform,
    String status = 'running',
    String? recommendedNextStep,
  }) {
    return _serialize(() async {
      _ensureSafeRunDirectory();
      _liveDirectory.createSync(recursive: true);
      final eventsFile = File(p.join(_liveDirectory.path, 'events.ndjson'));
      if (!eventsFile.existsSync()) {
        eventsFile.createSync(recursive: true);
      }
      final now = _clock.now().toUtc();
      _state = CockpitLiveRunState.initial(
        runId: runId,
        displayName: displayName,
        status: status,
        startedAt: now,
        workspaceId: _nonEmpty(workspaceId),
        scopeId: _resolveScopeId(
          scopeId: scopeId,
          sessionId: sessionId,
          taskId: taskId,
          workspaceId: workspaceId,
        ),
        scopeKind: _resolveScopeKind(
          scopeKind: scopeKind,
          scopeId: scopeId,
          sessionId: sessionId,
          taskId: taskId,
          workspaceId: workspaceId,
        ),
        scopeLabel: _resolveScopeLabel(
          scopeLabel: scopeLabel,
          taskId: taskId,
          sessionId: sessionId,
          workspaceId: workspaceId,
        ),
        sessionId: sessionId,
        taskId: taskId,
        platform: platform,
        recommendedNextStep: recommendedNextStep,
      );
      await _writeState();
      await _writeIndex();
    });
  }

  Future<CockpitLiveRunEvent> appendEvent({
    required String type,
    required String status,
    String? stage,
    String? workflowStepId,
    String? workflowStepType,
    String? description,
    String? commandId,
    String? commandType,
    List<Map<String, Object?>> artifactRefs = const <Map<String, Object?>>[],
    List<Map<String, Object?>> captureRefs = const <Map<String, Object?>>[],
    Map<String, Object?>? error,
    String? bundleDir,
    String? recommendedNextStep,
    Map<String, Object?> details = const <String, Object?>{},
  }) {
    return _serialize(() async {
      final current = _requireInitialized();
      final rawEvent = CockpitLiveRunEvent(
        runId: runId,
        seq: ++_lastSeq,
        timestamp: _clock.now().toUtc(),
        type: type,
        status: status,
        workspaceId: current.workspaceId,
        scopeId: current.scopeId,
        scopeKind: current.scopeKind,
        scopeLabel: current.scopeLabel,
        sessionId: current.sessionId,
        taskId: current.taskId,
        platform: current.platform,
        stage: stage,
        workflowStepId: workflowStepId,
        workflowStepType: workflowStepType,
        description: description,
        commandId: commandId,
        commandType: commandType,
        artifactRefs: artifactRefs,
        captureRefs: captureRefs,
        error: error,
        bundleDir: bundleDir,
        recommendedNextStep: recommendedNextStep,
        details: details,
      );
      final redactedEvent = CockpitLiveRunEvent.fromJson(
        _redactor.redact(rawEvent.toJson())! as Map<String, Object?>,
      );
      await File(p.join(_liveDirectory.path, 'events.ndjson')).writeAsString(
        '${jsonEncode(redactedEvent.toJson())}\n',
        mode: FileMode.append,
        flush: true,
      );
      _appendRecentEvent(redactedEvent);
      _state = current.applyEvent(
        redactedEvent,
        recentArtifactLimit: _recentArtifactLimit,
      );
      await _writeState();
      await _writeIndex();
      return redactedEvent;
    });
  }

  Future<void> updateState(
    CockpitLiveRunState Function(CockpitLiveRunState state) update,
  ) {
    return _serialize(() async {
      final updated = update(
        _requireInitialized(),
      ).copyWith(updatedAt: _clock.now().toUtc());
      _state = updated;
      await _writeState();
      await _writeIndex();
    });
  }

  String resolveRunPath(String relativePath) {
    if (p.isAbsolute(relativePath)) {
      throw CockpitLiveRunPathException(
        'Absolute paths are not allowed: $relativePath',
      );
    }
    final runRoot = p.normalize(p.absolute(_runDirectory.path));
    final resolved = p.normalize(p.absolute(p.join(runRoot, relativePath)));
    if (resolved != runRoot && !p.isWithin(runRoot, resolved)) {
      throw CockpitLiveRunPathException(
        'Path escapes run directory: $relativePath',
      );
    }
    return resolved;
  }

  Future<T> _serialize<T>(Future<T> Function() action) {
    final next = _pendingWrite.then((_) => action());
    _pendingWrite = next.then<void>((_) {}, onError: (_, _) {});
    return next;
  }

  CockpitLiveRunState _requireInitialized() {
    final current = _state;
    if (current == null) {
      throw StateError('CockpitLiveRunStore.initialize must be called first.');
    }
    return current;
  }

  void _appendRecentEvent(CockpitLiveRunEvent event) {
    _recentEvents.addLast(event);
    while (_recentEvents.length > _recentEventLimit) {
      _recentEvents.removeFirst();
    }
  }

  Future<void> _writeState() async {
    final current = _requireInitialized();
    await _writeJsonAtomically(
      p.join(_liveDirectory.path, 'live_state.json'),
      current.toJson(),
    );
  }

  Future<void> _writeIndex() {
    final current = _requireInitialized();
    Directory(historyRoot).createSync(recursive: true);
    return _serializeHistoryIndexWrite(() async {
      final lockFile = File(p.join(historyRoot, '.index.lock'));
      lockFile.createSync(recursive: true);
      final lock = await lockFile.open(mode: FileMode.write);
      await lock.lock(FileLock.exclusive);
      try {
        final indexPath = p.join(historyRoot, 'index.json');
        final existing = _readJsonMap(indexPath);
        final existingRuns =
            (existing['runs'] is List
                    ? existing['runs']! as List
                    : const <Object?>[])
                .whereType<Map>()
                .map(
                  (entry) => entry.map(
                    (key, value) =>
                        MapEntry<String, Object?>(key.toString(), value),
                  ),
                )
                .map(_normalizeRunScope)
                .where((entry) => entry['runId'] != runId)
                .toList(growable: true);
        final runEntry = <String, Object?>{
          'runId': runId,
          if (displayName != null) 'displayName': displayName,
          'status': current.status,
          'startedAt': current.startedAt.toUtc().toIso8601String(),
          'updatedAt': current.updatedAt.toUtc().toIso8601String(),
          if (current.finishedAt != null)
            'finishedAt': current.finishedAt!.toUtc().toIso8601String(),
          'runDir': p.relative(_runDirectory.path, from: historyRoot),
          'liveDir': p.relative(_liveDirectory.path, from: historyRoot),
          if (current.bundleDir != null) 'bundleDir': current.bundleDir,
          if (current.workspaceId != null) 'workspaceId': current.workspaceId,
          if (current.scopeId != null) 'scopeId': current.scopeId,
          if (current.scopeKind != null) 'scopeKind': current.scopeKind,
          if (current.scopeLabel != null) 'scopeLabel': current.scopeLabel,
          if (current.sessionId != null) 'sessionId': current.sessionId,
          if (current.taskId != null) 'taskId': current.taskId,
          if (current.platform != null) 'platform': current.platform,
        };
        final runs =
            <Map<String, Object?>>[
              _normalizeRunScope(runEntry),
              ...existingRuns,
            ]..sort((left, right) {
              final rightUpdated = right['updatedAt'] as String? ?? '';
              final leftUpdated = left['updatedAt'] as String? ?? '';
              return rightUpdated.compareTo(leftUpdated);
            });
        final scopes = _buildScopes(runs);
        final currentScopeId = scopes.isEmpty
            ? null
            : scopes.first['scopeId'] as String?;
        await _writeJsonAtomically(indexPath, <String, Object?>{
          'schemaVersion': 1,
          'updatedAt': current.updatedAt.toUtc().toIso8601String(),
          'runCount': runs.length,
          'scopeCount': scopes.length,
          'currentScopeId': ?currentScopeId,
          'scopes': scopes,
          'runs': runs,
        });
        await _writeScopeIndexes(
          scopes: scopes,
          runs: runs,
          updatedAt: current.updatedAt,
          currentScopeId: currentScopeId,
        );
      } finally {
        await lock.unlock();
        await lock.close();
      }
    });
  }

  Future<T> _serializeHistoryIndexWrite<T>(Future<T> Function() action) {
    final key = historyRoot;
    final previous = _historyIndexWriteQueues[key] ?? Future<void>.value();
    final result = previous.then((_) => action());
    final current = result.then<void>((_) {}, onError: (_, _) {});
    _historyIndexWriteQueues[key] = current;
    current.whenComplete(() {
      if (identical(_historyIndexWriteQueues[key], current)) {
        _historyIndexWriteQueues.remove(key);
      }
    });
    return result;
  }

  Future<void> _writeJsonAtomically(
    String path,
    Map<String, Object?> payload,
  ) async {
    final target = File(path);
    target.parent.createSync(recursive: true);
    final temp = File(
      p.join(
        target.parent.path,
        '.${p.basename(path)}.${DateTime.now().microsecondsSinceEpoch}.tmp',
      ),
    );
    await temp.writeAsString(
      const JsonEncoder.withIndent('  ').convert(payload),
      flush: true,
    );
    await temp.rename(path);
  }

  Map<String, Object?> _readJsonMap(String path) {
    final file = File(path);
    if (!file.existsSync()) {
      return const <String, Object?>{};
    }
    final decoded = jsonDecode(file.readAsStringSync());
    if (decoded is! Map) {
      return const <String, Object?>{};
    }
    return decoded.map(
      (key, value) => MapEntry<String, Object?>(key.toString(), value),
    );
  }

  void _ensureSafeRunDirectory() {
    Directory(_runsRoot).createSync(recursive: true);
    final runsRoot = p.normalize(p.absolute(_runsRoot));
    final runDir = p.normalize(p.absolute(_runDirectory.path));
    if (runDir != runsRoot && p.isWithin(runsRoot, runDir)) {
      return;
    }
    throw CockpitLiveRunPathException(
      'Resolved run directory escapes history root: ${_runDirectory.path}',
    );
  }

  Future<void> _writeScopeIndexes({
    required List<Map<String, Object?>> scopes,
    required List<Map<String, Object?>> runs,
    required DateTime updatedAt,
    required String? currentScopeId,
  }) async {
    final scopesRoot = Directory(p.join(historyRoot, 'scopes'));
    scopesRoot.createSync(recursive: true);
    await _writeJsonAtomically(p.join(scopesRoot.path, 'index.json'), {
      'schemaVersion': 1,
      'updatedAt': updatedAt.toUtc().toIso8601String(),
      'scopeCount': scopes.length,
      'currentScopeId': ?currentScopeId,
      'scopes': scopes,
    });
    for (final scope in scopes) {
      final scopeId = scope['scopeId'] as String?;
      final scopeDir = scope['scopeDir'] as String?;
      if (scopeId == null || scopeDir == null) {
        continue;
      }
      final scopeRuns = runs
          .where((run) => run['scopeId'] == scopeId)
          .toList(growable: false);
      await _writeJsonAtomically(
        p.join(historyRoot, scopeDir, 'index.json'),
        <String, Object?>{
          'schemaVersion': 1,
          'updatedAt': updatedAt.toUtc().toIso8601String(),
          for (final entry in scope.entries)
            if (entry.key != 'scopeDir') entry.key: entry.value,
          'scopeDir': scopeDir,
          'runCount': scopeRuns.length,
          'runs': scopeRuns,
        },
      );
    }
  }
}

String? _nonEmpty(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

String _resolveScopeId({
  required String? scopeId,
  required String? sessionId,
  required String? taskId,
  required String? workspaceId,
}) {
  return _nonEmpty(scopeId) ??
      _nonEmpty(sessionId) ??
      _nonEmpty(taskId) ??
      _nonEmpty(workspaceId) ??
      'default';
}

String _resolveScopeKind({
  required String? scopeKind,
  required String? scopeId,
  required String? sessionId,
  required String? taskId,
  required String? workspaceId,
}) {
  final explicit = _nonEmpty(scopeKind);
  if (explicit != null) {
    return explicit;
  }
  if (_nonEmpty(scopeId) != null) {
    return 'custom';
  }
  if (_nonEmpty(sessionId) != null) {
    return 'session';
  }
  if (_nonEmpty(taskId) != null) {
    return 'task';
  }
  if (_nonEmpty(workspaceId) != null) {
    return 'workspace';
  }
  return 'default';
}

String _resolveScopeLabel({
  required String? scopeLabel,
  required String? taskId,
  required String? sessionId,
  required String? workspaceId,
}) {
  return _nonEmpty(scopeLabel) ??
      _nonEmpty(taskId) ??
      _nonEmpty(sessionId) ??
      _nonEmpty(workspaceId) ??
      'default';
}

List<Map<String, Object?>> _buildScopes(List<Map<String, Object?>> runs) {
  final byId = <String, _ScopeAccumulator>{};
  for (final run in runs) {
    final scopeId = _runScopeId(run);
    final accumulator = byId.putIfAbsent(
      scopeId,
      () => _ScopeAccumulator(
        scopeId: scopeId,
        scopeKind: _runScopeKind(run),
        scopeLabel: _runScopeLabel(run),
        scopeDir: p.join('scopes', _safeDirectoryName(scopeId)),
      ),
    );
    accumulator.add(run);
  }
  final scopes = byId.values.map((scope) => scope.toJson()).toList();
  scopes.sort((left, right) {
    final rightUpdated = right['updatedAt'] as String? ?? '';
    final leftUpdated = left['updatedAt'] as String? ?? '';
    return rightUpdated.compareTo(leftUpdated);
  });
  return scopes;
}

String _runScopeId(Map<String, Object?> run) {
  return _nonEmpty(run['scopeId'] as String?) ??
      _nonEmpty(run['sessionId'] as String?) ??
      _nonEmpty(run['taskId'] as String?) ??
      _nonEmpty(run['workspaceId'] as String?) ??
      'default';
}

String _runScopeKind(Map<String, Object?> run) {
  return _nonEmpty(run['scopeKind'] as String?) ??
      (_nonEmpty(run['sessionId'] as String?) != null
          ? 'session'
          : _nonEmpty(run['taskId'] as String?) != null
          ? 'task'
          : _nonEmpty(run['workspaceId'] as String?) != null
          ? 'workspace'
          : 'default');
}

String _runScopeLabel(Map<String, Object?> run) {
  return _nonEmpty(run['scopeLabel'] as String?) ??
      _nonEmpty(run['displayName'] as String?) ??
      _nonEmpty(run['taskId'] as String?) ??
      _nonEmpty(run['sessionId'] as String?) ??
      _runScopeId(run);
}

Map<String, Object?> _normalizeRunScope(Map<String, Object?> run) {
  final normalized = <String, Object?>{...run};
  normalized['scopeId'] = _runScopeId(run);
  normalized['scopeKind'] = _runScopeKind(run);
  normalized['scopeLabel'] = _runScopeLabel(run);
  return normalized;
}

final class _ScopeAccumulator {
  _ScopeAccumulator({
    required this.scopeId,
    required this.scopeKind,
    required this.scopeLabel,
    required this.scopeDir,
  });

  final String scopeId;
  final String scopeKind;
  final String scopeLabel;
  final String scopeDir;
  var runCount = 0;
  String? latestRunId;
  String? status;
  String? platform;
  String? workspaceId;
  String? sessionId;
  String? taskId;
  String? updatedAt;

  void add(Map<String, Object?> run) {
    runCount += 1;
    final runUpdatedAt = run['updatedAt'] as String? ?? '';
    if (updatedAt == null || runUpdatedAt.compareTo(updatedAt!) > 0) {
      latestRunId = run['runId'] as String?;
      status = run['status'] as String?;
      platform = run['platform'] as String?;
      workspaceId = run['workspaceId'] as String?;
      sessionId = run['sessionId'] as String?;
      taskId = run['taskId'] as String?;
      updatedAt = runUpdatedAt;
    }
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'scopeId': scopeId,
    'scopeKind': scopeKind,
    'scopeLabel': scopeLabel,
    'scopeDir': scopeDir,
    'runCount': runCount,
    if (latestRunId != null) 'latestRunId': latestRunId,
    if (status != null) 'status': status,
    if (platform != null) 'platform': platform,
    if (workspaceId != null) 'workspaceId': workspaceId,
    if (sessionId != null) 'sessionId': sessionId,
    if (taskId != null) 'taskId': taskId,
    if (updatedAt != null) 'updatedAt': updatedAt,
  };
}

String _safeDirectoryName(String value) {
  final sanitized = value
      .replaceAll(RegExp('[^A-Za-z0-9._-]+'), '-')
      .replaceAll(RegExp('-+'), '-')
      .replaceAll(RegExp(r'^[._-]+'), '')
      .replaceAll(RegExp(r'[._-]+$'), '');
  final readableName = sanitized.isEmpty ? 'run' : sanitized;
  final needsHash = readableName != value || readableName.length > 96;
  if (!needsHash) {
    return readableName;
  }
  final prefixLength = readableName.length > 79 ? 79 : readableName.length;
  return '${readableName.substring(0, prefixLength)}-${_shortStableHash(value)}';
}

String _shortStableHash(String value) {
  var high = 0x811c9dc5;
  var low = 0x01000193;
  for (final byte in utf8.encode(value)) {
    high = ((high ^ byte) * 0x01000193).toUnsigned(32);
    low = ((low + byte) * 0x85ebca6b).toUnsigned(32);
  }
  return '${high.toRadixString(16).padLeft(8, '0')}'
      '${low.toRadixString(16).padLeft(8, '0')}';
}
