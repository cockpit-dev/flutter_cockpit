import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;

import '../application/cockpit_run_remote_control_script_service.dart';
import '../application/cockpit_validate_task_service.dart';
import '../cli/cockpit_cli_config_file.dart';
import '../cli/cockpit_control_script.dart';
import '../session/cockpit_remote_session_handle.dart';
import 'cockpit_devtools_asset_provider.dart';
import 'cockpit_live_run_identity.dart';

typedef CockpitDevtoolsRunScriptFunction =
    Future<CockpitRunRemoteControlScriptResult> Function(
      CockpitRunRemoteControlScriptRequest request,
    );
typedef CockpitDevtoolsValidateTaskFunction =
    Future<CockpitValidateTaskResult> Function(
      CockpitValidateTaskRequest request,
    );

const int _maxRequestBodyBytes = 1024 * 1024;
const int _maxBundleSummaryJsonBytes = 4 * 1024 * 1024;
const int _defaultRunIndexLimit = 200;
const int _maxRunIndexLimit = 1000;
const int _defaultScopeEventLimit = 350;
const int _maxScopeEventLimit = 2000;
const int _defaultScopeEventRunLimit = 80;
const int _maxScopeEventRunLimit = 300;
const int _maxScopeEventBytesPerRun = 512 * 1024;

final class CockpitDevtoolsServer {
  CockpitDevtoolsServer({
    required String historyRoot,
    String? token,
    InternetAddress? address,
    this.port = 0,
    CockpitDevtoolsAssetProvider assetProvider =
        const CockpitDevtoolsAssetProvider(),
    CockpitDevtoolsRunScriptFunction? runScript,
    CockpitDevtoolsValidateTaskFunction? validateTask,
  }) : historyRoot = p.normalize(p.absolute(historyRoot)),
       token = token ?? _generateToken(),
       address = address ?? InternetAddress.loopbackIPv4,
       _assetProvider = assetProvider,
       _runScript = runScript ?? CockpitRunRemoteControlScriptService().run,
       _validateTask = validateTask ?? CockpitValidateTaskService().validate;

  final String historyRoot;
  final String token;
  final InternetAddress address;
  final int port;
  final CockpitDevtoolsAssetProvider _assetProvider;
  final CockpitDevtoolsRunScriptFunction _runScript;
  final CockpitDevtoolsValidateTaskFunction _validateTask;
  final Map<String, _DevtoolsJob> _jobs = <String, _DevtoolsJob>{};

  Future<CockpitDevtoolsServerHandle> start() async {
    final server = await HttpServer.bind(address, port);
    server.listen(_handleRequest);
    return CockpitDevtoolsServerHandle._(
      server: server,
      token: token,
      uri: Uri(
        scheme: 'http',
        host: server.address.address,
        port: server.port,
        path: '/',
        queryParameters: <String, String>{'token': token},
      ),
    );
  }

  Future<void> _handleRequest(HttpRequest request) async {
    try {
      if (request.method != 'GET' &&
          request.method != 'HEAD' &&
          request.method != 'POST') {
        await _writeText(
          request,
          HttpStatus.methodNotAllowed,
          'method not allowed',
        );
        return;
      }
      final path = request.uri.path;
      if (path == '/' || path == '/index.html') {
        if (request.method == 'POST') {
          await _writeText(
            request,
            HttpStatus.methodNotAllowed,
            'method not allowed',
          );
          return;
        }
        await _writeText(
          request,
          HttpStatus.ok,
          _assetProvider.indexHtml,
          contentType: ContentType.html,
        );
        return;
      }
      if (!path.startsWith('/api/')) {
        await _writeText(request, HttpStatus.notFound, 'not found');
        return;
      }
      if (!_isAuthorized(request)) {
        await _writeJson(request, HttpStatus.unauthorized, <String, Object?>{
          'error': 'unauthorized',
        });
        return;
      }
      await _handleApiRequest(request);
    } on _ForbiddenPathException {
      await _writeJson(request, HttpStatus.forbidden, <String, Object?>{
        'error': 'forbiddenPath',
      });
    } on _PayloadTooLargeException {
      await _writeJson(
        request,
        HttpStatus.requestEntityTooLarge,
        <String, Object?>{
          'error': 'payloadTooLarge',
          'maxBytes': _maxRequestBodyBytes,
        },
      );
    } on FormatException catch (error) {
      await _writeJson(request, HttpStatus.badRequest, <String, Object?>{
        'error': 'invalidRequest',
        'message': error.message,
      });
    } catch (error) {
      await _writeJson(
        request,
        HttpStatus.internalServerError,
        <String, Object?>{'error': error.toString()},
      );
    }
  }

  Future<void> _handleApiRequest(HttpRequest request) async {
    final segments = request.uri.pathSegments;
    if (request.method == 'POST' &&
        segments.length == 3 &&
        segments[0] == 'api' &&
        segments[1] == 'workflows' &&
        segments[2] == 'parse') {
      await _parseWorkflow(request);
      return;
    }
    if (segments.length == 2 && segments[0] == 'api' && segments[1] == 'runs') {
      if (request.method == 'POST') {
        await _submitRun(request);
        return;
      }
      if (request.method != 'GET' && request.method != 'HEAD') {
        await _writeText(
          request,
          HttpStatus.methodNotAllowed,
          'method not allowed',
        );
        return;
      }
      await _serveRunIndex(request);
      return;
    }
    if (segments.length == 2 &&
        segments[0] == 'api' &&
        segments[1] == 'events') {
      if (request.method != 'GET' && request.method != 'HEAD') {
        await _writeText(
          request,
          HttpStatus.methodNotAllowed,
          'method not allowed',
        );
        return;
      }
      await _serveScopeEvents(request);
      return;
    }
    if (segments.length >= 4 && segments[0] == 'api' && segments[1] == 'runs') {
      final runId = Uri.decodeComponent(segments[2]);
      final action = segments[3];
      if (segments.length == 4 && action == 'job') {
        if (request.method != 'GET' && request.method != 'HEAD') {
          await _writeText(
            request,
            HttpStatus.methodNotAllowed,
            'method not allowed',
          );
          return;
        }
        await _serveJob(request, runId);
        return;
      }
      if (request.method == 'POST' &&
          segments.length == 4 &&
          action == 'cancel') {
        await _requestCancel(request, runId);
        return;
      }
      if (request.method != 'GET' && request.method != 'HEAD') {
        await _writeText(
          request,
          HttpStatus.methodNotAllowed,
          'method not allowed',
        );
        return;
      }
      final run = _resolveRun(runId);
      final job = _jobs[runId];
      if (run == null) {
        await _writeJson(request, HttpStatus.notFound, <String, Object?>{
          'error': 'runNotFound',
        });
        return;
      }
      if (segments.length == 4 && action == 'state') {
        final liveDir = run.liveDir;
        if (liveDir != null) {
          await _serveFile(request, _resolveLivePath(run, 'live_state.json'));
          return;
        }
        if (job != null) {
          await _writeJson(request, HttpStatus.ok, _liveStateFromJob(job));
          return;
        }
        await _writeJson(request, HttpStatus.notFound, <String, Object?>{
          'error': 'liveStateNotFound',
        });
        return;
      }
      if (segments.length == 4 && action == 'events.ndjson') {
        if (run.liveDir == null) {
          await _writeText(
            request,
            HttpStatus.ok,
            '',
            contentType: ContentType(
              'application',
              'x-ndjson',
              charset: 'utf-8',
            ),
          );
          return;
        }
        await _serveFile(
          request,
          _resolveLivePath(run, 'events.ndjson'),
          contentType: ContentType('application', 'x-ndjson', charset: 'utf-8'),
        );
        return;
      }
      if (segments.length == 4 && action == 'events') {
        if (run.liveDir == null) {
          await _writeText(
            request,
            HttpStatus.ok,
            ': connected\n\n',
            contentType: ContentType('text', 'event-stream', charset: 'utf-8'),
          );
          return;
        }
        await _serveSse(request, _resolveLivePath(run, 'events.ndjson'));
        return;
      }
      if (segments.length == 4 && action == 'bundle-summary') {
        await _serveBundleSummary(request, run);
        return;
      }
      if (segments.length >= 5 && action == 'artifacts') {
        await _serveFile(
          request,
          _resolveBundlePath(run, _relativePathFromSegments(segments.skip(4))),
        );
        return;
      }
      if (segments.length >= 5 && action == 'bundle') {
        await _serveFile(
          request,
          _resolveBundlePath(run, _relativePathFromSegments(segments.skip(4))),
        );
        return;
      }
    }
    await _writeText(request, HttpStatus.notFound, 'not found');
  }

  Future<void> _serveBundleSummary(HttpRequest request, _RunEntry run) async {
    final bundleDir = run.bundleDir;
    if (bundleDir == null) {
      await _writeJson(request, HttpStatus.notFound, <String, Object?>{
        'error': 'bundleNotFound',
      });
      return;
    }
    final bundleRoot = _resolveUnderHistory(bundleDir);
    final manifestFile = _readOptionalBundleJson(bundleRoot, 'manifest.json');
    final deliveryFile = _readOptionalBundleJson(bundleRoot, 'delivery.json');
    final issueEvidenceFile = _readOptionalBundleJson(
      bundleRoot,
      'issue_evidence.json',
    );
    final traceFile = _readOptionalBundleJson(bundleRoot, 'trace.json');
    final manifest = manifestFile?.json;
    final delivery = deliveryFile?.json;
    final issueEvidence = issueEvidenceFile?.json;
    final trace = traceFile?.json;
    final summaryFileIssues = _summaryFileIssues(<_BundleJsonSnapshot?>[
      manifestFile,
      deliveryFile,
      issueEvidenceFile,
      traceFile,
    ]);
    await _writeJson(request, HttpStatus.ok, <String, Object?>{
      'schemaVersion': 1,
      if (manifest != null) ..._summaryFieldsFromManifest(manifest),
      if (delivery != null) ..._summaryFieldsFromDelivery(delivery),
      'issueEvidence': ?issueEvidence,
      if (trace != null)
        'traceSummary': _summaryFieldsFromTrace(trace)
      else if (traceFile?.hasIssue ?? false)
        'traceSummary': _jsonIssueSummary(traceFile!),
      if (summaryFileIssues.isNotEmpty) 'summaryFileIssues': summaryFileIssues,
      'artifactRefs': _bundleArtifactRefs(
        manifest: manifest,
        delivery: delivery,
        trace: trace,
      ),
    });
  }

  Future<void> _parseWorkflow(HttpRequest request) async {
    final body = await _readJsonObject(request);
    final source = _readRequiredString(body, 'source');
    final platformOverride = _readOptionalString(body, 'platform');
    final parsed = cockpitControlScriptFromText(source);
    final script = platformOverride == null
        ? parsed
        : parsed.withPlatform(platformOverride);
    await _writeJson(request, HttpStatus.ok, <String, Object?>{
      'schemaVersion': 1,
      'ok': true,
      'sessionId': script.sessionId,
      'taskId': script.taskId,
      'platform': script.platform,
      'commandCount': script.commands.length,
      'stepCount': script.workflowSteps.length,
      'requestsRecording': script.requestsRecording,
      'script': script.toJson(),
    });
  }

  Future<void> _submitRun(HttpRequest request) async {
    final body = await _readJsonObject(request);
    final kind = _readOptionalString(body, 'kind') ?? 'runScript';
    switch (kind) {
      case 'runScript':
        await _submitRunScript(request, body);
        return;
      case 'validateTask':
        await _submitValidateTask(request, body);
        return;
      default:
        throw FormatException('Unsupported devtools run kind "$kind".');
    }
  }

  Future<void> _submitRunScript(
    HttpRequest request,
    Map<String, Object?> body,
  ) async {
    final script = _readScript(body);
    final outputRoot = _resolveOutputRoot(body['outputRoot']);
    final runId = cockpitCreateLiveRunId(script.sessionId);
    final job = _DevtoolsJob.start(
      runId: runId,
      kind: 'runScript',
      taskId: script.taskId,
      sessionId: script.sessionId,
      platform: script.platform,
    );
    _rememberJob(job);
    final runRequest = CockpitRunRemoteControlScriptRequest(
      script: script,
      outputRoot: outputRoot,
      platformAppId: _readOptionalString(body, 'platformAppId'),
      processId: _readOptionalInt(body, 'processId'),
      baseUri: _readOptionalUri(body, 'baseUrl'),
      sessionHandle: _readOptionalSessionHandle(body, 'sessionHandle'),
      sessionHandlePath: _readOptionalString(body, 'sessionHandlePath'),
      androidDeviceId: _readOptionalString(body, 'androidDeviceId'),
      iosDeviceId: _readOptionalString(body, 'iosDeviceId'),
      persistScriptPath: _readOptionalString(body, 'persistScriptPath'),
      portForwardingHandled:
          _readOptionalBool(body, 'portForwardingHandled') ?? false,
      liveRunId: runId,
      liveRunDisplayName: script.taskId,
    );
    unawaited(
      _runScript(runRequest)
          .then((result) {
            job.complete(<String, Object?>{
              'bundleDir': result.bundleDir.path,
              'manifest': result.manifest.toJson(),
            });
          })
          .catchError((Object error, StackTrace stackTrace) {
            job.fail(error, stackTrace);
          }),
    );
    await _writeJson(request, HttpStatus.accepted, job.toJson());
  }

  Future<void> _submitValidateTask(
    HttpRequest request,
    Map<String, Object?> body,
  ) async {
    final parsedValidateTask = _readValidateTaskRequest(body);
    final parsedRunTask = parsedValidateTask.runTask;
    final runId = cockpitCreateLiveRunId(parsedRunTask.script.sessionId);
    final validateTask = CockpitValidateTaskRequest(
      runTask: parsedRunTask.withLiveRun(
        liveRunId: runId,
        liveRunDisplayName: parsedRunTask.script.taskId,
      ),
      validation: parsedValidateTask.validation,
    );
    final runTask = validateTask.runTask;
    final job = _DevtoolsJob.start(
      runId: runId,
      kind: 'validateTask',
      taskId: runTask.script.taskId,
      sessionId: runTask.script.sessionId,
      platform: runTask.script.platform,
    );
    _rememberJob(job);
    unawaited(
      _validateTask(validateTask)
          .then((result) {
            job.complete(<String, Object?>{
              'classification': result.classification.jsonValue,
              'recommendedNextStep': result.recommendedNextStep,
              if (result.bundleSummary != null)
                'bundleDir': result.bundleSummary!.bundleDir,
            });
          })
          .catchError((Object error, StackTrace stackTrace) {
            job.fail(error, stackTrace);
          }),
    );
    await _writeJson(request, HttpStatus.accepted, job.toJson());
  }

  Future<void> _serveJob(HttpRequest request, String runId) async {
    final job = _jobs[runId];
    if (job == null) {
      await _writeJson(request, HttpStatus.notFound, <String, Object?>{
        'error': 'jobNotFound',
      });
      return;
    }
    await _writeJson(request, HttpStatus.ok, job.toJson());
  }

  Future<void> _requestCancel(HttpRequest request, String runId) async {
    final job = _jobs[runId];
    if (job == null) {
      await _writeJson(request, HttpStatus.notFound, <String, Object?>{
        'error': 'jobNotFound',
      });
      return;
    }
    job.requestCancel();
    await _writeJson(request, HttpStatus.conflict, <String, Object?>{
      'error': 'cancelUnsupported',
      'runId': runId,
      'status': job.status,
      'message':
          'The current runner does not expose hard cancellation. The cancel request was recorded; stop the underlying app/session if immediate interruption is required.',
    });
  }

  void _rememberJob(_DevtoolsJob job) {
    _jobs[job.runId] = job;
    if (_jobs.length <= 200) {
      return;
    }
    final removable =
        _jobs.values
            .where((candidate) => candidate.status != 'running')
            .toList(growable: false)
          ..sort((left, right) => left.updatedAt.compareTo(right.updatedAt));
    for (final job in removable.take(_jobs.length - 200)) {
      _jobs.remove(job.runId);
    }
  }

  Future<Map<String, Object?>> _readJsonObject(HttpRequest request) async {
    final bytes = <int>[];
    var total = 0;
    await for (final chunk in request) {
      total += chunk.length;
      if (total > _maxRequestBodyBytes) {
        throw const _PayloadTooLargeException();
      }
      bytes.addAll(chunk);
    }
    final source = utf8.decode(bytes);
    final trimmed = source.trimLeft();
    if (trimmed.isEmpty) {
      return const <String, Object?>{};
    }
    if (!trimmed.startsWith('{')) {
      return <String, Object?>{'source': source};
    }
    final decoded = jsonDecode(source);
    if (decoded is! Map<Object?, Object?>) {
      throw const FormatException('Request body must decode to an object.');
    }
    return decoded.map(
      (key, value) => MapEntry<String, Object?>(key.toString(), value),
    );
  }

  CockpitControlScript _readScript(Map<String, Object?> body) {
    final scriptText =
        _readOptionalString(body, 'scriptText') ??
        _readOptionalString(body, 'source');
    final scriptValue = body['script'];
    final CockpitControlScript parsed;
    if (scriptText != null) {
      parsed = cockpitControlScriptFromText(scriptText);
    } else if (scriptValue is String && scriptValue.trim().isNotEmpty) {
      parsed = cockpitControlScriptFromText(scriptValue);
    } else if (scriptValue is Map<Object?, Object?>) {
      parsed = CockpitControlScript.fromJson(
        scriptValue.map(
          (key, value) => MapEntry<String, Object?>(key.toString(), value),
        ),
      );
    } else {
      throw const FormatException(
        'runScript requests must include scriptText or script.',
      );
    }
    final platformOverride = _readOptionalString(body, 'platform');
    return platformOverride == null
        ? parsed
        : parsed.withPlatform(platformOverride);
  }

  CockpitValidateTaskRequest _readValidateTaskRequest(
    Map<String, Object?> body,
  ) {
    final configText =
        _readOptionalString(body, 'configText') ??
        _readOptionalString(body, 'source');
    final requestJson = configText == null
        ? (_readOptionalObject(body, 'request') ??
              _readOptionalObject(body, 'validateTask') ??
              body)
        : cockpitConfigMapFromText(configText, label: 'Validate task config');
    final runTaskJson = _readOptionalObject(requestJson, 'runTask');
    if (runTaskJson == null) {
      throw const FormatException(
        'validateTask requests must include a runTask object.',
      );
    }
    runTaskJson['outputRoot'] = _resolveOutputRoot(runTaskJson['outputRoot']);
    requestJson['runTask'] = runTaskJson;
    return CockpitValidateTaskRequest.fromJson(requestJson);
  }

  String _resolveOutputRoot(Object? value) {
    if (value == null) {
      return historyRoot;
    }
    if (value is! String || value.trim().isEmpty) {
      throw const FormatException('outputRoot must be a non-empty string.');
    }
    final raw = value.trim();
    final root = p.normalize(p.absolute(historyRoot));
    final resolved = p.normalize(
      p.absolute(p.isAbsolute(raw) ? raw : p.join(root, raw)),
    );
    if (resolved == root || p.isWithin(root, resolved)) {
      return resolved;
    }
    throw const _ForbiddenPathException();
  }

  String _readRequiredString(Map<String, Object?> json, String key) {
    final value = _readOptionalString(json, key);
    if (value == null) {
      throw FormatException('$key must be a non-empty string.');
    }
    return value;
  }

  String? _readOptionalString(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value == null) {
      return null;
    }
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    throw FormatException('$key must be a non-empty string.');
  }

  int? _readOptionalInt(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value == null) {
      return null;
    }
    if (value is int) {
      return value;
    }
    throw FormatException('$key must be an integer.');
  }

  bool? _readOptionalBool(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value == null) {
      return null;
    }
    if (value is bool) {
      return value;
    }
    throw FormatException('$key must be a boolean.');
  }

  Uri? _readOptionalUri(Map<String, Object?> json, String key) {
    final value = _readOptionalString(json, key);
    if (value == null) {
      return null;
    }
    return Uri.parse(value);
  }

  Map<String, Object?>? _readOptionalObject(
    Map<String, Object?> json,
    String key,
  ) {
    final value = json[key];
    if (value == null) {
      return null;
    }
    if (value is Map<Object?, Object?>) {
      return value.map(
        (key, value) => MapEntry<String, Object?>(key.toString(), value),
      );
    }
    throw FormatException('$key must be an object.');
  }

  CockpitRemoteSessionHandle? _readOptionalSessionHandle(
    Map<String, Object?> json,
    String key,
  ) {
    final value = _readOptionalObject(json, key);
    if (value == null) {
      return null;
    }
    return CockpitRemoteSessionHandle.fromJson(value);
  }

  Future<void> _serveRunIndex(HttpRequest request) async {
    final index = _readIndex();
    final runs = _readRunsWithJobs(index);
    if (runs.isEmpty) {
      await _writeJson(request, HttpStatus.ok, <String, Object?>{
        'schemaVersion': 1,
        'runCount': 0,
        'filteredRunCount': 0,
        'scopeMode': 'current',
        'scopeId': 'all',
        'scopes': const <Object?>[],
        'runs': const <Object?>[],
      });
      return;
    }
    final scopes = _readScopes(index, runs);
    final scopeSelection = _selectedScope(
      request.uri.queryParameters,
      index,
      scopes,
    );
    final selectedScopeId = scopeSelection.scopeId;
    final filteredRuns = _filterRuns(
      runs,
      query: request.uri.queryParameters,
      selectedScopeId: selectedScopeId,
    );
    final runPage = _pageRuns(filteredRuns, query: request.uri.queryParameters);
    final currentScopeId = scopeSelection.mode == 'latest'
        ? selectedScopeId
        : index['currentScopeId'] is String &&
              (index['currentScopeId']! as String).trim().isNotEmpty
        ? (index['currentScopeId']! as String).trim()
        : scopes.isEmpty
        ? null
        : scopes.first['scopeId'] as String?;
    Map<String, Object?>? selectedScopeMetadata;
    if (selectedScopeId != 'all') {
      for (final scope in scopes) {
        if (scope['scopeId'] == selectedScopeId) {
          selectedScopeMetadata = scope;
          break;
        }
      }
    }
    await _writeJson(request, HttpStatus.ok, <String, Object?>{
      'schemaVersion': 1,
      'updatedAt': index['updatedAt'],
      'runCount': runs.length,
      'filteredRunCount': filteredRuns.length,
      'returnedRunCount': runPage.runs.length,
      'offset': runPage.offset,
      'limit': runPage.limit,
      'hasMoreRuns': runPage.hasMore,
      'scopeCount': scopes.length,
      'scopeMode': scopeSelection.mode,
      if (scopeSelection.requestedScope != null)
        'requestedScope': scopeSelection.requestedScope,
      'scopeId': selectedScopeId,
      if (selectedScopeMetadata?['scopeKind'] != null)
        'scopeKind': selectedScopeMetadata?['scopeKind'],
      if (selectedScopeMetadata?['scopeLabel'] != null)
        'scopeLabel': selectedScopeMetadata?['scopeLabel'],
      'currentScopeId': ?currentScopeId,
      'scopes': scopes,
      'runs': runPage.runs,
    });
  }

  Future<void> _serveScopeEvents(HttpRequest request) async {
    final index = _readIndex();
    final runs = _readRunsWithJobs(index);
    if (runs.isEmpty) {
      await _writeJson(request, HttpStatus.ok, <String, Object?>{
        'schemaVersion': 1,
        'scopeMode': 'current',
        'scopeId': 'all',
        'eventCount': 0,
        'returnedEventCount': 0,
        'runCount': 0,
        'events': const <Object?>[],
      });
      return;
    }
    final scopes = _readScopes(index, runs);
    final scopeSelection = _selectedScope(
      request.uri.queryParameters,
      index,
      scopes,
    );
    final selectedScopeId = scopeSelection.scopeId;
    final filteredRuns = _filterRuns(
      runs,
      query: request.uri.queryParameters,
      selectedScopeId: selectedScopeId,
    );
    final runLimit = _boundedQueryInt(
      request.uri.queryParameters,
      'runLimit',
      defaultValue: _defaultScopeEventRunLimit,
      max: _maxScopeEventRunLimit,
    );
    final runsForEvents = runLimit == 0
        ? filteredRuns
        : filteredRuns.take(runLimit).toList(growable: false);
    final limit = _boundedQueryInt(
      request.uri.queryParameters,
      'limit',
      defaultValue: _defaultScopeEventLimit,
      max: _maxScopeEventLimit,
    );
    final events = _readScopeEvents(runsForEvents);
    final limitedEvents = limit == 0 || events.length <= limit
        ? events
        : events.sublist(events.length - limit);
    Map<String, Object?>? selectedScopeMetadata;
    if (selectedScopeId != 'all') {
      for (final scope in scopes) {
        if (scope['scopeId'] == selectedScopeId) {
          selectedScopeMetadata = scope;
          break;
        }
      }
    }
    await _writeJson(request, HttpStatus.ok, <String, Object?>{
      'schemaVersion': 1,
      'scopeMode': scopeSelection.mode,
      if (scopeSelection.requestedScope != null)
        'requestedScope': scopeSelection.requestedScope,
      'scopeId': selectedScopeId,
      if (selectedScopeMetadata?['scopeKind'] != null)
        'scopeKind': selectedScopeMetadata?['scopeKind'],
      if (selectedScopeMetadata?['scopeLabel'] != null)
        'scopeLabel': selectedScopeMetadata?['scopeLabel'],
      'runCount': filteredRuns.length,
      'readRunCount': runsForEvents.length,
      'eventCount': events.length,
      'returnedEventCount': limitedEvents.length,
      'limit': limit,
      'runLimit': runLimit,
      'hasMoreEvents': limit > 0 && events.length > limitedEvents.length,
      'hasMoreRuns': runLimit > 0 && filteredRuns.length > runsForEvents.length,
      'events': limitedEvents,
    });
  }

  Future<void> _serveSse(HttpRequest request, String eventsPath) async {
    final response = request.response;
    response.statusCode = HttpStatus.ok;
    response.bufferOutput = false;
    response.headers
      ..contentType = ContentType('text', 'event-stream', charset: 'utf-8')
      ..set(HttpHeaders.cacheControlHeader, 'no-cache');
    _setCommonSecurityHeaders(response.headers);
    final lastEventId =
        int.tryParse(request.headers.value('last-event-id') ?? '') ?? 0;
    var offset = 0;
    var buffered = '';
    var lastSeq = lastEventId;
    try {
      response.write(': connected\n\n');
      await response.flush();
      for (var poll = 0; poll < 3600; poll += 1) {
        final file = File(eventsPath);
        if (file.existsSync()) {
          final length = await file.length();
          if (length > offset) {
            await for (final chunk in file.openRead(offset, length)) {
              offset += chunk.length;
              buffered += utf8.decode(chunk, allowMalformed: true);
              final lines = buffered.split('\n');
              buffered = lines.removeLast();
              lastSeq = await _writeSseLines(
                response: response,
                lines: lines,
                lastSeq: lastSeq,
              );
            }
          }
        }
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
      await response.close();
    } on SocketException {
      return;
    } on HttpException {
      return;
    }
  }

  Future<int> _writeSseLines({
    required HttpResponse response,
    required Iterable<String> lines,
    required int lastSeq,
  }) async {
    var currentLastSeq = lastSeq;
    var wrote = false;
    for (final line in lines) {
      if (line.trim().isEmpty) {
        continue;
      }
      final Map<String, Object?> decoded;
      try {
        final value = jsonDecode(line);
        if (value is! Map) {
          continue;
        }
        decoded = value.map(
          (key, value) => MapEntry<String, Object?>(key.toString(), value),
        );
      } on FormatException {
        continue;
      }
      final seq = decoded['seq'] is num ? (decoded['seq']! as num).toInt() : 0;
      if (seq <= currentLastSeq) {
        continue;
      }
      currentLastSeq = seq;
      response.write('id: $seq\n');
      response.write('event: ${decoded['type'] ?? 'message'}\n');
      response.write('data: $line\n\n');
      wrote = true;
    }
    if (wrote) {
      await response.flush();
    }
    return currentLastSeq;
  }

  Future<void> _serveFile(
    HttpRequest request,
    String path, {
    ContentType? contentType,
  }) async {
    final file = File(path);
    if (!file.existsSync()) {
      await _writeText(request, HttpStatus.notFound, 'not found');
      return;
    }
    final length = await file.length();
    final range = _parseRange(
      request.headers.value(HttpHeaders.rangeHeader),
      length,
    );
    final response = request.response;
    response.headers
      ..contentType = contentType ?? _contentTypeFor(path)
      ..set(HttpHeaders.cacheControlHeader, 'no-store')
      ..set(HttpHeaders.acceptRangesHeader, 'bytes');
    _setCommonSecurityHeaders(response.headers);
    if (range != null) {
      response.statusCode = HttpStatus.partialContent;
      response.headers
        ..contentLength = range.length
        ..set(
          HttpHeaders.contentRangeHeader,
          'bytes ${range.start}-${range.end}/$length',
        );
      if (request.method != 'HEAD') {
        await file.openRead(range.start, range.end + 1).pipe(response);
      } else {
        await response.close();
      }
      return;
    }
    response.statusCode = HttpStatus.ok;
    response.headers.contentLength = length;
    if (request.method != 'HEAD') {
      await file.openRead().pipe(response);
    } else {
      await response.close();
    }
  }

  String _resolveLivePath(_RunEntry run, String relativePath) {
    final liveDir = run.liveDir;
    if (liveDir == null) {
      throw const _ForbiddenPathException();
    }
    final liveRoot = _resolveUnderHistory(liveDir);
    return _resolveUnderRoot(liveRoot, relativePath);
  }

  String _resolveBundlePath(_RunEntry run, String relativePath) {
    final bundleDir = run.bundleDir;
    if (bundleDir == null) {
      throw const _ForbiddenPathException();
    }
    final bundleRoot = _resolveUnderHistory(bundleDir);
    return _resolveUnderRoot(bundleRoot, relativePath);
  }

  String _resolveUnderHistory(String relativePath) {
    if (p.isAbsolute(relativePath)) {
      final normalizedRoot = p.normalize(p.absolute(historyRoot));
      final resolved = p.normalize(p.absolute(relativePath));
      if (resolved == normalizedRoot || p.isWithin(normalizedRoot, resolved)) {
        return resolved;
      }
      throw const _ForbiddenPathException();
    }
    return _resolveUnderRoot(historyRoot, relativePath);
  }

  String _resolveUnderRoot(String root, String relativePath) {
    if (relativePath.isEmpty ||
        p.isAbsolute(relativePath) ||
        relativePath.split('/').any((segment) => segment == '..')) {
      throw const _ForbiddenPathException();
    }
    final normalizedRoot = p.normalize(p.absolute(root));
    final resolved = p.normalize(
      p.absolute(p.join(normalizedRoot, relativePath)),
    );
    if (resolved == normalizedRoot || p.isWithin(normalizedRoot, resolved)) {
      return resolved;
    }
    throw const _ForbiddenPathException();
  }

  _RunEntry? _resolveRun(String runId) {
    final index = _readIndex();
    final runs = _readRunsWithJobs(index);
    for (final run in runs) {
      if (run['runId'] != runId) {
        continue;
      }
      final liveDir = run['liveDir'] as String?;
      final bundleDir = run['bundleDir'] as String? ?? run['runDir'] as String?;
      if (run['jobOnly'] == true) {
        return _RunEntry(liveDir: liveDir, bundleDir: bundleDir);
      }
      if (liveDir == null && bundleDir == null) {
        return null;
      }
      return _RunEntry(liveDir: liveDir, bundleDir: bundleDir);
    }
    return null;
  }

  Map<String, Object?> _readIndex() {
    final file = File(p.join(historyRoot, 'index.json'));
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

  List<Map<String, Object?>> _readRunsWithJobs(Map<String, Object?> index) {
    final historyRuns = _readRuns(index);
    if (_jobs.isEmpty) {
      return historyRuns;
    }
    final knownRunIds = historyRuns
        .map((run) => run['runId'])
        .whereType<String>()
        .toSet();
    final jobRuns = _jobs.values
        .where((job) => !knownRunIds.contains(job.runId))
        .map(_runEntryFromJob)
        .toList(growable: false);
    if (jobRuns.isEmpty) {
      return historyRuns;
    }
    final runs = <Map<String, Object?>>[...historyRuns, ...jobRuns];
    runs.sort((left, right) {
      final rightUpdated =
          right['updatedAt'] as String? ?? right['startedAt'] as String? ?? '';
      final leftUpdated =
          left['updatedAt'] as String? ?? left['startedAt'] as String? ?? '';
      final updatedOrder = rightUpdated.compareTo(leftUpdated);
      if (updatedOrder != 0) {
        return updatedOrder;
      }
      final rightRunId = right['runId'] as String? ?? '';
      final leftRunId = left['runId'] as String? ?? '';
      return rightRunId.compareTo(leftRunId);
    });
    return runs;
  }

  Map<String, Object?> _runEntryFromJob(_DevtoolsJob job) {
    final bundleDir = _historyRelativeJobBundleDir(job);
    return _normalizeRunScope(<String, Object?>{
      'runId': job.runId,
      'displayName': job.taskId,
      'status': job.status,
      'startedAt': job.startedAt.toIso8601String(),
      'updatedAt': job.updatedAt.toIso8601String(),
      if (job.finishedAt != null)
        'finishedAt': job.finishedAt!.toIso8601String(),
      'sessionId': job.sessionId,
      'taskId': job.taskId,
      'platform': job.platform,
      'scopeId': job.sessionId,
      'scopeKind': 'session',
      'scopeLabel': job.taskId,
      'jobKind': job.kind,
      'jobOnly': true,
      'bundleDir': ?bundleDir,
    });
  }

  String? _historyRelativeJobBundleDir(_DevtoolsJob job) {
    final rawBundleDir = job.result?['bundleDir'];
    if (rawBundleDir is! String || rawBundleDir.trim().isEmpty) {
      return null;
    }
    final raw = rawBundleDir.trim();
    final normalizedRoot = p.normalize(p.absolute(historyRoot));
    final resolved = p.normalize(
      p.absolute(p.isAbsolute(raw) ? raw : p.join(normalizedRoot, raw)),
    );
    if (resolved == normalizedRoot || !p.isWithin(normalizedRoot, resolved)) {
      return null;
    }
    return p.relative(resolved, from: normalizedRoot);
  }

  Map<String, Object?> _liveStateFromJob(_DevtoolsJob job) {
    final bundleDir = _historyRelativeJobBundleDir(job);
    final manifest = job.result?['manifest'];
    return <String, Object?>{
      'schemaVersion': 1,
      'runId': job.runId,
      'displayName': job.taskId,
      'status': job.status,
      'stage': 'devtools-job',
      'scopeId': job.sessionId,
      'scopeKind': 'session',
      'scopeLabel': job.taskId,
      'sessionId': job.sessionId,
      'taskId': job.taskId,
      'platform': job.platform,
      'startedAt': job.startedAt.toIso8601String(),
      'updatedAt': job.updatedAt.toIso8601String(),
      if (job.finishedAt != null)
        'finishedAt': job.finishedAt!.toIso8601String(),
      'bundleDir': ?bundleDir,
      'counts': <String, Object?>{
        'eventCount': 0,
        'errorCount': job.error == null ? 0 : 1,
        if (manifest is Map<Object?, Object?>) ...<String, Object?>{
          if (manifest['screenshotCount'] != null)
            'artifactCount': manifest['screenshotCount'],
          if (manifest['recordingCount'] != null)
            'recordingCount': manifest['recordingCount'],
        },
      },
      'job': job.toJson(),
      if (job.error != null) 'lastError': job.error,
      if (job.status == 'completed' && bundleDir != null)
        'recommendedNextStep': 'inspect bundle evidence from the dashboard',
      if (job.status == 'failed')
        'recommendedNextStep': 'inspect devtools job error before retrying',
    };
  }

  List<Map<String, Object?>> _readRuns(Map<String, Object?> index) {
    final runs = index['runs'];
    if (runs is! List) {
      return const <Map<String, Object?>>[];
    }
    return runs
        .whereType<Map>()
        .map(
          (entry) => entry.map(
            (key, value) => MapEntry<String, Object?>(key.toString(), value),
          ),
        )
        .map(_normalizeRunScope)
        .toList(growable: false);
  }

  List<Map<String, Object?>> _readScopes(
    Map<String, Object?> index,
    List<Map<String, Object?>> runs,
  ) {
    final derivedScopes = _deriveScopesFromRuns(runs);
    final scopes = index['scopes'];
    if (scopes is List && scopes.isNotEmpty) {
      final mergedById = <String, Map<String, Object?>>{};
      for (final scope in scopes.whereType<Map>().map(
        (entry) => entry.map(
          (key, value) => MapEntry<String, Object?>(key.toString(), value),
        ),
      )) {
        final scopeId = scope['scopeId'];
        if (scopeId is String && scopeId.trim().isNotEmpty) {
          mergedById[scopeId] = scope;
        }
      }
      for (final scope in derivedScopes) {
        final scopeId = scope['scopeId'];
        if (scopeId is! String || scopeId.trim().isEmpty) {
          continue;
        }
        mergedById[scopeId] = <String, Object?>{
          ...?mergedById[scopeId],
          ...scope,
        };
      }
      final merged = mergedById.values.toList(growable: false);
      merged.sort(_compareScopesByUpdatedAt);
      return merged;
    }
    return derivedScopes;
  }

  _RunScopeSelection _selectedScope(
    Map<String, String> query,
    Map<String, Object?> index,
    List<Map<String, Object?>> scopes,
  ) {
    final explicitScope = _queryValue(query, 'scope');
    if (explicitScope != null) {
      if (explicitScope == 'current' || explicitScope == 'latest') {
        return _currentScopeSelection(
          index,
          scopes,
          mode: explicitScope,
          requestedScope: explicitScope,
        );
      }
      return _RunScopeSelection(
        scopeId: explicitScope,
        mode: explicitScope == 'all' ? 'all' : 'scope',
        requestedScope: explicitScope,
      );
    }
    final sessionId = _queryValue(query, 'sessionId');
    if (sessionId != null) {
      return _RunScopeSelection(
        scopeId: sessionId,
        mode: 'session',
        requestedScope: sessionId,
      );
    }
    final taskId = _queryValue(query, 'taskId');
    if (taskId != null) {
      return _RunScopeSelection(
        scopeId: taskId,
        mode: 'task',
        requestedScope: taskId,
      );
    }
    return _currentScopeSelection(index, scopes, mode: 'current');
  }

  _RunScopeSelection _currentScopeSelection(
    Map<String, Object?> index,
    List<Map<String, Object?>> scopes, {
    required String mode,
    String? requestedScope,
  }) {
    final currentScopeId = index['currentScopeId'];
    if (mode == 'latest' &&
        scopes.isNotEmpty &&
        scopes.first['scopeId'] is String) {
      return _RunScopeSelection(
        scopeId: scopes.first['scopeId']! as String,
        mode: mode,
        requestedScope: requestedScope,
      );
    }
    if (currentScopeId is String && currentScopeId.trim().isNotEmpty) {
      return _RunScopeSelection(
        scopeId: currentScopeId.trim(),
        mode: mode,
        requestedScope: requestedScope,
      );
    }
    if (scopes.isNotEmpty && scopes.first['scopeId'] is String) {
      return _RunScopeSelection(
        scopeId: scopes.first['scopeId']! as String,
        mode: mode,
        requestedScope: requestedScope,
      );
    }
    return _RunScopeSelection(
      scopeId: 'all',
      mode: 'all',
      requestedScope: requestedScope,
    );
  }

  List<Map<String, Object?>> _filterRuns(
    List<Map<String, Object?>> runs, {
    required Map<String, String> query,
    required String selectedScopeId,
  }) {
    final workspaceId = _queryValue(query, 'workspaceId');
    final sessionId = _queryValue(query, 'sessionId');
    final taskId = _queryValue(query, 'taskId');
    final platform = _queryValue(query, 'platform');
    final status = _queryValue(query, 'status');
    final filtered = runs
        .where((run) {
          if (selectedScopeId != 'all' && _runScopeId(run) != selectedScopeId) {
            return false;
          }
          if (workspaceId != null && run['workspaceId'] != workspaceId) {
            return false;
          }
          if (sessionId != null && run['sessionId'] != sessionId) {
            return false;
          }
          if (taskId != null && run['taskId'] != taskId) {
            return false;
          }
          if (platform != null && run['platform'] != platform) {
            return false;
          }
          if (status != null && run['status'] != status) {
            return false;
          }
          return true;
        })
        .toList(growable: false);
    return filtered;
  }

  List<Map<String, Object?>> _readScopeEvents(List<Map<String, Object?>> runs) {
    final events = <Map<String, Object?>>[];
    for (final run in runs) {
      final runId = run['runId'] as String?;
      final liveDir = run['liveDir'] as String?;
      if (runId == null || liveDir == null) {
        continue;
      }
      final eventsFile = File(
        _resolveUnderRoot(_resolveUnderHistory(liveDir), 'events.ndjson'),
      );
      if (!eventsFile.existsSync()) {
        continue;
      }
      final fileLength = eventsFile.lengthSync();
      final start = max(0, fileLength - _maxScopeEventBytesPerRun);
      final reader = eventsFile.openSync();
      final String text;
      try {
        reader.setPositionSync(start);
        text = utf8.decode(
          reader.readSync(fileLength - start),
          allowMalformed: true,
        );
      } finally {
        reader.closeSync();
      }
      final lines = _tailWholeLines(text, skippedPrefix: start > 0);
      for (final line in lines) {
        final event = _decodeEventLine(line);
        if (event == null) {
          continue;
        }
        events.add(_normalizeScopeEvent(event, run: run, runId: runId));
      }
    }
    events.sort((left, right) {
      final leftTimestamp = left['timestamp'] as String? ?? '';
      final rightTimestamp = right['timestamp'] as String? ?? '';
      final timestampOrder = leftTimestamp.compareTo(rightTimestamp);
      if (timestampOrder != 0) {
        return timestampOrder;
      }
      final leftRunUpdated = left['runUpdatedAt'] as String? ?? '';
      final rightRunUpdated = right['runUpdatedAt'] as String? ?? '';
      final runOrder = leftRunUpdated.compareTo(rightRunUpdated);
      if (runOrder != 0) {
        return runOrder;
      }
      final leftRunId = left['runId'] as String? ?? '';
      final rightRunId = right['runId'] as String? ?? '';
      final runIdOrder = leftRunId.compareTo(rightRunId);
      if (runIdOrder != 0) {
        return runIdOrder;
      }
      final leftSeq = left['seq'] is num ? (left['seq']! as num).toInt() : 0;
      final rightSeq = right['seq'] is num ? (right['seq']! as num).toInt() : 0;
      return leftSeq.compareTo(rightSeq);
    });
    return events;
  }

  List<String> _tailWholeLines(String text, {required bool skippedPrefix}) {
    if (text.isEmpty) {
      return const <String>[];
    }
    var body = text;
    if (skippedPrefix) {
      if (body.startsWith('\n')) {
        body = body.substring(1);
      } else {
        final firstLineBreak = body.indexOf('\n');
        body = firstLineBreak < 0 ? '' : body.substring(firstLineBreak + 1);
      }
    }
    final lines = body.split('\n');
    return lines
        .where((line) => line.trim().isNotEmpty)
        .toList(growable: false);
  }

  Map<String, Object?>? _decodeEventLine(String line) {
    try {
      final decoded = jsonDecode(line);
      if (decoded is! Map) {
        return null;
      }
      return decoded.map(
        (key, value) => MapEntry<String, Object?>(key.toString(), value),
      );
    } on FormatException {
      return null;
    }
  }

  Map<String, Object?> _normalizeScopeEvent(
    Map<String, Object?> event, {
    required Map<String, Object?> run,
    required String runId,
  }) {
    final seq = event['seq'];
    final eventKey = '$runId#${seq is num ? seq.toInt() : seq ?? 'event'}';
    return <String, Object?>{
      ...event,
      'runId': runId,
      'eventKey': eventKey,
      if (run['displayName'] != null) 'runDisplayName': run['displayName'],
      if (run['status'] != null) 'runStatus': run['status'],
      if (run['updatedAt'] != null) 'runUpdatedAt': run['updatedAt'],
      'scopeId': event['scopeId'] ?? run['scopeId'],
      'scopeKind': event['scopeKind'] ?? run['scopeKind'],
      'scopeLabel': event['scopeLabel'] ?? run['scopeLabel'],
      'sessionId': event['sessionId'] ?? run['sessionId'],
      'taskId': event['taskId'] ?? run['taskId'],
      'platform': event['platform'] ?? run['platform'],
      if (event['artifactRefs'] is List)
        'artifactRefs': _normalizeEventArtifacts(
          event['artifactRefs'],
          runId: runId,
          eventKey: eventKey,
          seq: seq,
        ),
      if (event['captureRefs'] is List)
        'captureRefs': _normalizeEventArtifacts(
          event['captureRefs'],
          runId: runId,
          eventKey: eventKey,
          seq: seq,
        ),
    };
  }

  List<Map<String, Object?>> _normalizeEventArtifacts(
    Object? value, {
    required String runId,
    required String eventKey,
    required Object? seq,
  }) {
    if (value is! List) {
      return const <Map<String, Object?>>[];
    }
    return value
        .whereType<Map>()
        .map(
          (artifact) => artifact.map(
            (key, value) => MapEntry<String, Object?>(key.toString(), value),
          ),
        )
        .map(
          (artifact) => <String, Object?>{
            ...artifact,
            'runId': artifact['runId'] ?? runId,
            'eventKey': artifact['eventKey'] ?? eventKey,
            if (artifact['eventSeq'] == null && seq != null) 'eventSeq': seq,
          },
        )
        .toList(growable: false);
  }

  _RunPage _pageRuns(
    List<Map<String, Object?>> runs, {
    required Map<String, String> query,
  }) {
    final offset = _boundedQueryInt(
      query,
      'offset',
      defaultValue: 0,
      max: null,
    );
    final requestedLimit = _boundedQueryInt(
      query,
      'limit',
      defaultValue: _defaultRunIndexLimit,
      max: _maxRunIndexLimit,
    );
    if (requestedLimit == 0) {
      final page = offset >= runs.length
          ? const <Map<String, Object?>>[]
          : runs.sublist(offset);
      return _RunPage(runs: page, offset: offset, limit: 0, hasMore: false);
    }
    final end = min(runs.length, offset + requestedLimit);
    final page = offset >= runs.length
        ? const <Map<String, Object?>>[]
        : runs.sublist(offset, end);
    return _RunPage(
      runs: page,
      offset: offset,
      limit: requestedLimit,
      hasMore: end < runs.length,
    );
  }

  int _boundedQueryInt(
    Map<String, String> query,
    String key, {
    required int defaultValue,
    required int? max,
  }) {
    final raw = _queryValue(query, key);
    if (raw == null) {
      return defaultValue;
    }
    final parsed = int.tryParse(raw);
    if (parsed == null || parsed < 0) {
      return defaultValue;
    }
    if (max != null && parsed > max) {
      return max;
    }
    return parsed;
  }

  bool _isAuthorized(HttpRequest request) {
    if (request.uri.queryParameters['token'] == token) {
      return true;
    }
    if (request.headers.value('x-cockpit-token') == token) {
      return true;
    }
    final authorization = request.headers.value(
      HttpHeaders.authorizationHeader,
    );
    return authorization == 'Bearer $token';
  }

  Future<void> _writeJson(
    HttpRequest request,
    int statusCode,
    Map<String, Object?> body,
  ) {
    return _writeText(
      request,
      statusCode,
      const JsonEncoder.withIndent('  ').convert(body),
      contentType: ContentType.json,
    );
  }

  Future<void> _writeText(
    HttpRequest request,
    int statusCode,
    String body, {
    ContentType? contentType,
  }) async {
    request.response
      ..statusCode = statusCode
      ..headers.contentType = contentType ?? ContentType.text
      ..headers.set(HttpHeaders.cacheControlHeader, 'no-store');
    _setCommonSecurityHeaders(request.response.headers);
    if (request.method != 'HEAD') {
      request.response.write(body);
    }
    await request.response.close();
  }
}

String _relativePathFromSegments(Iterable<String> segments) {
  return segments.map(Uri.decodeComponent).join('/');
}

void _setCommonSecurityHeaders(HttpHeaders headers) {
  headers
    ..set('x-content-type-options', 'nosniff')
    ..set('x-frame-options', 'SAMEORIGIN')
    ..set('x-xss-protection', '1; mode=block');
}

_BundleJsonSnapshot? _readOptionalBundleJson(
  String bundleRoot,
  String relativePath,
) {
  final path = p.join(bundleRoot, relativePath);
  final file = File(path);
  if (!file.existsSync()) {
    return null;
  }
  final size = file.lengthSync();
  if (size > _maxBundleSummaryJsonBytes) {
    return _BundleJsonSnapshot.skipped(
      relativePath: relativePath,
      fileSizeBytes: size,
    );
  }
  final Object? decoded;
  try {
    decoded = jsonDecode(file.readAsStringSync());
  } on FormatException catch (error) {
    return _BundleJsonSnapshot.invalid(
      relativePath: relativePath,
      fileSizeBytes: size,
      message: error.message,
    );
  } on FileSystemException catch (error) {
    return _BundleJsonSnapshot.invalid(
      relativePath: relativePath,
      fileSizeBytes: size,
      message: error.message,
    );
  }
  if (decoded is! Map) {
    return _BundleJsonSnapshot.invalid(
      relativePath: relativePath,
      fileSizeBytes: size,
      message: 'Expected a JSON object.',
    );
  }
  return _BundleJsonSnapshot.loaded(
    relativePath: relativePath,
    fileSizeBytes: size,
    json: decoded.map(
      (key, value) => MapEntry<String, Object?>(key.toString(), value),
    ),
  );
}

Map<String, Object?> _summaryFieldsFromManifest(Map<String, Object?> manifest) {
  return <String, Object?>{
    if (manifest['sessionId'] != null) 'sessionId': manifest['sessionId'],
    if (manifest['taskId'] != null) 'taskId': manifest['taskId'],
    if (manifest['platform'] != null) 'platform': manifest['platform'],
    if (manifest['status'] != null) 'status': manifest['status'],
    if (manifest['failureSummary'] != null)
      'failureSummary': manifest['failureSummary'],
    if (manifest['recordingCount'] != null)
      'recordingCount': manifest['recordingCount'],
    if (manifest['screenshotCount'] != null)
      'screenshotCount': manifest['screenshotCount'],
    if (manifest['deliveryVideoReady'] != null)
      'deliveryVideoReady': manifest['deliveryVideoReady'],
  };
}

Map<String, Object?> _summaryFieldsFromDelivery(Map<String, Object?> delivery) {
  return <String, Object?>{
    if (delivery['summary'] != null) 'deliverySummary': delivery['summary'],
    if (delivery['primaryScreenshotRef'] != null)
      'primaryScreenshotRef': delivery['primaryScreenshotRef'],
    if (delivery['primaryRecordingRef'] != null)
      'primaryRecordingRef': delivery['primaryRecordingRef'],
    if (delivery['deliveryVideoSynthesized'] != null)
      'deliveryVideoSynthesized': delivery['deliveryVideoSynthesized'],
    if (delivery['deliveryVideoSource'] != null)
      'deliveryVideoSource': delivery['deliveryVideoSource'],
    if (delivery['deliveryVideoDurationMs'] != null)
      'deliveryVideoDurationMs': delivery['deliveryVideoDurationMs'],
    if (delivery['keyframeCoverage'] != null)
      'keyframeCoverage': delivery['keyframeCoverage'],
  };
}

Map<String, Object?> _summaryFieldsFromTrace(Map<String, Object?> trace) {
  final entries = _mapListValue(trace['entries']);
  final failedCount = entries
      .where((entry) => entry['status'] == 'failed' || entry['error'] != null)
      .length;
  final recentEntries = entries.length <= 6
      ? entries
      : entries.sublist(entries.length - 6);
  return <String, Object?>{
    'entryCount': entries.length,
    if (failedCount > 0) 'failedEntryCount': failedCount,
    'recentEntries': recentEntries
        .map(
          (entry) => <String, Object?>{
            if (entry['stepIndex'] != null) 'stepIndex': entry['stepIndex'],
            if (entry['workflowStepId'] != null)
              'workflowStepId': entry['workflowStepId'],
            if (entry['actionType'] != null) 'actionType': entry['actionType'],
            if (entry['status'] != null) 'status': entry['status'],
          },
        )
        .toList(growable: false),
  };
}

List<Map<String, Object?>> _summaryFileIssues(
  Iterable<_BundleJsonSnapshot?> snapshots,
) {
  return snapshots
      .whereType<_BundleJsonSnapshot>()
      .where((snapshot) => snapshot.hasIssue)
      .map(_jsonIssueSummary)
      .toList(growable: false);
}

Map<String, Object?> _jsonIssueSummary(_BundleJsonSnapshot snapshot) {
  return <String, Object?>{
    'skipped': snapshot.skippedDueToSize,
    'reason': snapshot.reason,
    'relativePath': snapshot.relativePath,
    'fileSizeBytes': snapshot.fileSizeBytes,
    'maxSummaryJsonBytes': _maxBundleSummaryJsonBytes,
    if (snapshot.message != null) 'message': snapshot.message,
  };
}

List<Map<String, Object?>> _bundleArtifactRefs({
  required Map<String, Object?>? manifest,
  required Map<String, Object?>? delivery,
  required Map<String, Object?>? trace,
}) {
  final artifacts = <Map<String, Object?>>[];
  final seen = <String>{};

  void addArtifact({
    required Object? relativePath,
    required String role,
    String? source,
    Map<String, Object?> extra = const <String, Object?>{},
  }) {
    if (relativePath is! String || relativePath.trim().isEmpty) {
      return;
    }
    final path = relativePath.trim();
    final key = '$role|$path';
    if (!seen.add(key)) {
      return;
    }
    artifacts.add(<String, Object?>{
      'role': role,
      'relativePath': path,
      'source': ?source,
      ...extra,
    });
  }

  for (final artifact in _mapListValue(manifest?['artifactRefs'])) {
    final role = artifact['role'] is String
        ? artifact['role']! as String
        : _roleForRelativePath(artifact['relativePath']);
    addArtifact(
      relativePath: artifact['relativePath'],
      role: role,
      source: 'manifest',
      extra: <String, Object?>{
        for (final entry in artifact.entries)
          if (entry.key != 'relativePath' && entry.key != 'role')
            entry.key: entry.value,
      },
    );
  }

  addArtifact(
    relativePath: delivery?['primaryScreenshotRef'],
    role: 'screenshot',
    source: 'delivery',
  );
  addArtifact(
    relativePath: delivery?['primaryRecordingRef'],
    role: 'recording',
    source: 'delivery',
    extra: <String, Object?>{
      if (delivery?['deliveryVideoSynthesized'] != null)
        'synthesized': delivery?['deliveryVideoSynthesized'],
      if (delivery?['deliveryVideoSource'] != null)
        'videoSource': delivery?['deliveryVideoSource'],
      if (delivery?['deliveryVideoDurationMs'] != null)
        'durationMs': delivery?['deliveryVideoDurationMs'],
    },
  );
  for (final ref in _stringListValue(delivery?['attachmentRefs'])) {
    addArtifact(relativePath: ref, role: 'screenshot', source: 'delivery');
  }
  for (final ref in _stringListValue(delivery?['videoAttachmentRefs'])) {
    addArtifact(relativePath: ref, role: 'recording', source: 'delivery');
  }
  for (final keyframe in _mapListValue(delivery?['keyframes'])) {
    addArtifact(
      relativePath: keyframe['ref'],
      role: 'keyframe',
      source: 'delivery',
      extra: <String, Object?>{
        if (keyframe['label'] != null) 'label': keyframe['label'],
        if (keyframe['offsetMs'] != null) 'offsetMs': keyframe['offsetMs'],
        if (keyframe['source'] != null) 'keyframeSource': keyframe['source'],
        if (keyframe['linkedScreenshotRef'] != null)
          'linkedScreenshotRef': keyframe['linkedScreenshotRef'],
      },
    );
  }

  for (final entry in _mapListValue(trace?['entries'])) {
    for (final artifact in _mapListValue(entry['artifactRefs'])) {
      final role = artifact['role'] is String
          ? artifact['role']! as String
          : _roleForRelativePath(artifact['relativePath']);
      addArtifact(
        relativePath: artifact['relativePath'],
        role: role,
        source: 'trace',
        extra: <String, Object?>{
          if (entry['stepIndex'] != null) 'stepIndex': entry['stepIndex'],
          if (entry['workflowStepId'] != null)
            'workflowStepId': entry['workflowStepId'],
          if (entry['actionType'] != null) 'actionType': entry['actionType'],
        },
      );
    }
    for (final artifact in _mapListValue(entry['captureRefs'])) {
      addArtifact(
        relativePath: artifact['relativePath'],
        role: 'screenshot',
        source: 'trace',
        extra: <String, Object?>{
          if (entry['stepIndex'] != null) 'stepIndex': entry['stepIndex'],
          if (entry['workflowStepId'] != null)
            'workflowStepId': entry['workflowStepId'],
          if (entry['actionType'] != null) 'actionType': entry['actionType'],
        },
      );
    }
  }

  return artifacts;
}

List<Map<String, Object?>> _mapListValue(Object? value) {
  if (value is! List) {
    return const <Map<String, Object?>>[];
  }
  return value
      .whereType<Map>()
      .map(
        (entry) => entry.map(
          (key, value) => MapEntry<String, Object?>(key.toString(), value),
        ),
      )
      .toList(growable: false);
}

List<String> _stringListValue(Object? value) {
  if (value is! List) {
    return const <String>[];
  }
  return value.whereType<String>().toList(growable: false);
}

String _roleForRelativePath(Object? value) {
  if (value is! String) {
    return 'artifact';
  }
  final extension = p.extension(value).toLowerCase();
  if (extension == '.png' || extension == '.jpg' || extension == '.jpeg') {
    return value.startsWith('keyframes/') ? 'keyframe' : 'screenshot';
  }
  if (extension == '.mp4' || extension == '.webm' || extension == '.mov') {
    return 'recording';
  }
  if (extension == '.json' || extension == '.ndjson') {
    return 'diagnostics';
  }
  return 'artifact';
}

String? _queryValue(Map<String, String> query, String key) {
  final value = query[key]?.trim();
  return value == null || value.isEmpty ? null : value;
}

String? _stringValue(Object? value) {
  if (value is! String) {
    return null;
  }
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

String _runScopeId(Map<String, Object?> run) {
  return _stringValue(run['scopeId']) ??
      _stringValue(run['sessionId']) ??
      _stringValue(run['taskId']) ??
      _stringValue(run['workspaceId']) ??
      'default';
}

String _runScopeKind(Map<String, Object?> run) {
  return _stringValue(run['scopeKind']) ??
      (_stringValue(run['sessionId']) != null
          ? 'session'
          : _stringValue(run['taskId']) != null
          ? 'task'
          : _stringValue(run['workspaceId']) != null
          ? 'workspace'
          : 'default');
}

String _runScopeLabel(Map<String, Object?> run) {
  return _stringValue(run['scopeLabel']) ??
      _stringValue(run['displayName']) ??
      _stringValue(run['taskId']) ??
      _stringValue(run['sessionId']) ??
      _runScopeId(run);
}

Map<String, Object?> _normalizeRunScope(Map<String, Object?> run) {
  final normalized = <String, Object?>{...run};
  normalized['scopeId'] = _runScopeId(run);
  normalized['scopeKind'] = _runScopeKind(run);
  normalized['scopeLabel'] = _runScopeLabel(run);
  return normalized;
}

List<Map<String, Object?>> _deriveScopesFromRuns(
  List<Map<String, Object?>> runs,
) {
  final byId = <String, _DerivedScope>{};
  for (final run in runs) {
    final scopeId = _runScopeId(run);
    final scope = byId.putIfAbsent(
      scopeId,
      () => _DerivedScope(
        scopeId: scopeId,
        scopeKind: _runScopeKind(run),
        scopeLabel: _runScopeLabel(run),
      ),
    );
    scope.add(run);
  }
  final scopes = byId.values.map((scope) => scope.toJson()).toList();
  scopes.sort(_compareScopesByUpdatedAt);
  return scopes;
}

int _compareScopesByUpdatedAt(
  Map<String, Object?> left,
  Map<String, Object?> right,
) {
  final rightUpdated = right['updatedAt'] as String? ?? '';
  final leftUpdated = left['updatedAt'] as String? ?? '';
  final updatedOrder = rightUpdated.compareTo(leftUpdated);
  if (updatedOrder != 0) {
    return updatedOrder;
  }
  final rightScopeId = right['scopeId'] as String? ?? '';
  final leftScopeId = left['scopeId'] as String? ?? '';
  return rightScopeId.compareTo(leftScopeId);
}

final class CockpitDevtoolsServerHandle {
  CockpitDevtoolsServerHandle._({
    required HttpServer server,
    required this.uri,
    required this.token,
  }) : _server = server;

  final HttpServer _server;
  final Uri uri;
  final String token;

  Future<void> close() => _server.close(force: true);
}

final class _DerivedScope {
  _DerivedScope({
    required this.scopeId,
    required this.scopeKind,
    required this.scopeLabel,
  });

  final String scopeId;
  final String scopeKind;
  final String scopeLabel;
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

final class _RunEntry {
  const _RunEntry({required this.liveDir, required this.bundleDir});

  final String? liveDir;
  final String? bundleDir;
}

final class _RunPage {
  const _RunPage({
    required this.runs,
    required this.offset,
    required this.limit,
    required this.hasMore,
  });

  final List<Map<String, Object?>> runs;
  final int offset;
  final int limit;
  final bool hasMore;
}

final class _RunScopeSelection {
  const _RunScopeSelection({
    required this.scopeId,
    required this.mode,
    this.requestedScope,
  });

  final String scopeId;
  final String mode;
  final String? requestedScope;
}

final class _BundleJsonSnapshot {
  const _BundleJsonSnapshot._({
    required this.relativePath,
    required this.fileSizeBytes,
    required this.json,
    required this.skippedDueToSize,
    required this.reason,
    required this.message,
  });

  factory _BundleJsonSnapshot.loaded({
    required String relativePath,
    required int fileSizeBytes,
    required Map<String, Object?> json,
  }) {
    return _BundleJsonSnapshot._(
      relativePath: relativePath,
      fileSizeBytes: fileSizeBytes,
      json: json,
      skippedDueToSize: false,
      reason: null,
      message: null,
    );
  }

  factory _BundleJsonSnapshot.skipped({
    required String relativePath,
    required int fileSizeBytes,
  }) {
    return _BundleJsonSnapshot._(
      relativePath: relativePath,
      fileSizeBytes: fileSizeBytes,
      json: null,
      skippedDueToSize: true,
      reason: 'fileTooLarge',
      message: null,
    );
  }

  factory _BundleJsonSnapshot.invalid({
    required String relativePath,
    required int fileSizeBytes,
    required String message,
  }) {
    return _BundleJsonSnapshot._(
      relativePath: relativePath,
      fileSizeBytes: fileSizeBytes,
      json: null,
      skippedDueToSize: false,
      reason: 'invalidJson',
      message: message,
    );
  }

  final String relativePath;
  final int fileSizeBytes;
  final Map<String, Object?>? json;
  final bool skippedDueToSize;
  final String? reason;
  final String? message;

  bool get hasIssue => reason != null;
}

final class _DevtoolsJob {
  _DevtoolsJob.start({
    required this.runId,
    required this.kind,
    required this.sessionId,
    required this.taskId,
    required this.platform,
  }) : status = 'running',
       startedAt = DateTime.now().toUtc(),
       updatedAt = DateTime.now().toUtc();

  final String runId;
  final String kind;
  final String sessionId;
  final String taskId;
  final String platform;
  final DateTime startedAt;
  DateTime updatedAt;
  DateTime? finishedAt;
  String status;
  Map<String, Object?>? result;
  Map<String, Object?>? error;
  var cancelRequested = false;

  void complete(Map<String, Object?> result) {
    status = 'completed';
    this.result = result;
    finishedAt = DateTime.now().toUtc();
    updatedAt = finishedAt!;
  }

  void fail(Object error, StackTrace stackTrace) {
    status = 'failed';
    this.error = <String, Object?>{
      'type': error.runtimeType.toString(),
      'message': error.toString(),
    };
    finishedAt = DateTime.now().toUtc();
    updatedAt = finishedAt!;
  }

  void requestCancel() {
    cancelRequested = true;
    updatedAt = DateTime.now().toUtc();
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'runId': runId,
    'kind': kind,
    'sessionId': sessionId,
    'taskId': taskId,
    'platform': platform,
    'status': status,
    'cancelRequested': cancelRequested,
    'startedAt': startedAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    if (finishedAt != null) 'finishedAt': finishedAt!.toIso8601String(),
    if (result != null) 'result': result,
    if (error != null) 'error': error,
  };
}

final class _ByteRange {
  const _ByteRange({required this.start, required this.end});

  final int start;
  final int end;

  int get length => end - start + 1;
}

final class _ForbiddenPathException implements Exception {
  const _ForbiddenPathException();

  @override
  String toString() => 'Forbidden path.';
}

final class _PayloadTooLargeException implements Exception {
  const _PayloadTooLargeException();
}

_ByteRange? _parseRange(String? header, int fileLength) {
  if (header == null || !header.startsWith('bytes=') || fileLength <= 0) {
    return null;
  }
  final range = header.substring('bytes='.length);
  final separator = range.indexOf('-');
  if (separator < 0) {
    return null;
  }
  if (separator == 0) {
    final suffixLength = int.tryParse(range.substring(1));
    if (suffixLength == null || suffixLength <= 0) {
      return null;
    }
    final start = max(0, fileLength - suffixLength);
    return _ByteRange(start: start, end: fileLength - 1);
  }
  final start = int.tryParse(range.substring(0, separator));
  final explicitEnd = int.tryParse(range.substring(separator + 1));
  if (start == null || start < 0 || start >= fileLength) {
    return null;
  }
  final end = min(explicitEnd ?? fileLength - 1, fileLength - 1);
  if (end < start) {
    return null;
  }
  return _ByteRange(start: start, end: end);
}

ContentType _contentTypeFor(String path) {
  return switch (p.extension(path).toLowerCase()) {
    '.html' => ContentType.html,
    '.json' => ContentType.json,
    '.ndjson' => ContentType('application', 'x-ndjson', charset: 'utf-8'),
    '.png' => ContentType('image', 'png'),
    '.jpg' || '.jpeg' => ContentType('image', 'jpeg'),
    '.webp' => ContentType('image', 'webp'),
    '.mp4' => ContentType('video', 'mp4'),
    '.mov' => ContentType('video', 'quicktime'),
    '.webm' => ContentType('video', 'webm'),
    '.txt' || '.log' => ContentType.text,
    _ => ContentType.binary,
  };
}

String _generateToken() {
  final random = Random.secure();
  final bytes = List<int>.generate(24, (_) => random.nextInt(256));
  return base64Url.encode(bytes).replaceAll('=', '');
}
