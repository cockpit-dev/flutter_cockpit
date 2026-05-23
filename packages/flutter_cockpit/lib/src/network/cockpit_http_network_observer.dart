import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'cockpit_network_entry.dart';
import 'cockpit_network_endpoint_summary.dart';
import 'cockpit_network_observer.dart';
import 'cockpit_network_query.dart';
import 'cockpit_network_snapshot.dart';

typedef CockpitNetworkTickHandler = Future<void> Function(Duration duration);

final class CockpitHttpNetworkObserver extends HttpOverrides
    implements CockpitNetworkObserver {
  CockpitHttpNetworkObserver({
    this.maxRetainedEntries = 200,
    this.maxHeaderCount = 24,
    this.maxHeaderValueLength = 256,
    this.maxBodyBytes = 4096,
    this.captureHeaders = true,
    this.captureBodies = true,
    CockpitNetworkTickHandler? tickHandler,
  }) : _tickHandler = tickHandler ?? _defaultTickHandler;

  final int maxRetainedEntries;
  final int maxHeaderCount;
  final int maxHeaderValueLength;
  final int maxBodyBytes;
  final bool captureHeaders;
  final bool captureBodies;
  final CockpitNetworkTickHandler _tickHandler;

  final ListQueue<CockpitNetworkEntry> _entries =
      ListQueue<CockpitNetworkEntry>();
  HttpOverrides? _parentOverrides;
  bool _parentOverridesLocked = false;
  int _requestCounter = 0;
  int _inFlightCount = 0;
  DateTime? _lastActivityAt;

  void attachParentOverrides(HttpOverrides? overrides) {
    _parentOverrides = overrides;
    _parentOverridesLocked = true;
  }

  bool get hasAttachedParentOverrides => _parentOverridesLocked;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final delegate =
        _parentOverrides?.createHttpClient(context) ??
        super.createHttpClient(context);
    return _CockpitObservedHttpClient(delegate, observer: this);
  }

  @override
  CockpitNetworkSnapshot snapshot({
    int maxEntries = 10,
    CockpitNetworkQuery query = const CockpitNetworkQuery(),
  }) {
    final allEntries = _entries.toList(growable: false);
    final matchingEntries = allEntries
        .where((entry) => _matchesQuery(entry, query))
        .toList(growable: false);
    final boundedMax = maxEntries < 0 ? 0 : maxEntries;
    final startIndex = matchingEntries.length > boundedMax
        ? matchingEntries.length - boundedMax
        : 0;
    final visibleEntries = boundedMax == 0
        ? const <CockpitNetworkEntry>[]
        : matchingEntries.sublist(startIndex);
    return CockpitNetworkSnapshot(
      totalEntryCount: matchingEntries.length,
      failureCount: matchingEntries.where((entry) => entry.isFailure).length,
      entries: visibleEntries,
      endpointSummaries: _summariesFor(matchingEntries),
      capturedEntryCount: allEntries.length,
      inFlightCount: _inFlightCount,
      query: query,
      truncated: matchingEntries.length > visibleEntries.length,
    );
  }

  @override
  Future<bool> waitForIdle({
    Duration quietWindow = const Duration(milliseconds: 150),
    Duration timeout = const Duration(seconds: 2),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      if (_isIdleFor(quietWindow)) {
        return true;
      }
      await _tickHandler(const Duration(milliseconds: 24));
    }
    return _isIdleFor(quietWindow);
  }

  @override
  void clear() {
    _entries.clear();
    _inFlightCount = 0;
    _lastActivityAt = DateTime.now().toUtc();
  }

  String nextRequestId() {
    _requestCounter += 1;
    return 'net-${DateTime.now().toUtc().microsecondsSinceEpoch}-$_requestCounter';
  }

  Map<String, String> snapshotHeaders(HttpHeaders headers) {
    if (!captureHeaders) {
      return const <String, String>{};
    }

    final captured = <String, String>{};
    headers.forEach((name, values) {
      if (captured.length >= maxHeaderCount) {
        return;
      }
      final rawValue = values.join(', ');
      final boundedValue = rawValue.length > maxHeaderValueLength
          ? '${rawValue.substring(0, maxHeaderValueLength)}...'
          : rawValue;
      captured[name] = boundedValue;
    });
    return Map<String, String>.unmodifiable(captured);
  }

  void _finish(_CockpitPendingNetworkRecord pending) {
    _inFlightCount = ((_inFlightCount - 1).clamp(0, maxRetainedEntries * 10));
    _lastActivityAt = DateTime.now().toUtc();
    _entries.add(pending.buildEntry(this));
    while (_entries.length > maxRetainedEntries) {
      _entries.removeFirst();
    }
  }

  void markRequestStarted() {
    _inFlightCount += 1;
    _lastActivityAt = DateTime.now().toUtc();
  }

  String? previewBytes(List<int> bytes) {
    if (!captureBodies || bytes.isEmpty) {
      return null;
    }
    return utf8.decode(bytes, allowMalformed: true).replaceAll('\u0000', '');
  }

  bool _matchesQuery(CockpitNetworkEntry entry, CockpitNetworkQuery query) {
    if (query.onlyFailures && !entry.isFailure) {
      return false;
    }
    final method = query.method;
    if (method != null &&
        method.isNotEmpty &&
        entry.method.toUpperCase() != method.toUpperCase()) {
      return false;
    }
    final uriContains = query.uriContains;
    if (uriContains != null &&
        uriContains.isNotEmpty &&
        !entry.uri.contains(uriContains)) {
      return false;
    }
    final statusCodeAtLeast = query.statusCodeAtLeast;
    if (statusCodeAtLeast != null) {
      final statusCode = entry.statusCode;
      if (statusCode == null || statusCode < statusCodeAtLeast) {
        return false;
      }
    }
    return true;
  }

  bool _isIdleFor(Duration quietWindow) {
    if (_inFlightCount != 0) {
      return false;
    }
    final lastActivityAt = _lastActivityAt;
    if (lastActivityAt == null) {
      return true;
    }
    return DateTime.now().toUtc().difference(lastActivityAt) >= quietWindow;
  }

  List<CockpitNetworkEndpointSummary> _summariesFor(
    List<CockpitNetworkEntry> entries,
  ) {
    final buckets = <String, List<CockpitNetworkEntry>>{};
    for (final entry in entries) {
      final pattern = _uriPatternFor(entry.uri);
      final bucketKey = '${entry.method} $pattern';
      buckets.putIfAbsent(bucketKey, () => <CockpitNetworkEntry>[]).add(entry);
    }

    final summaries = buckets.entries
        .map((bucket) {
          final bucketEntries = bucket.value;
          final latestEntry = bucketEntries.reduce((left, right) {
            return left.startedAt.isAfter(right.startedAt) ? left : right;
          });
          final averageDurationMs =
              bucketEntries
                  .map((entry) => entry.durationMs)
                  .fold<int>(0, (total, duration) => total + duration) ~/
              bucketEntries.length;
          return CockpitNetworkEndpointSummary(
            method: latestEntry.method,
            uriPattern: _uriPatternFor(latestEntry.uri),
            requestCount: bucketEntries.length,
            failureCount: bucketEntries
                .where((entry) => entry.isFailure)
                .length,
            averageDurationMs: averageDurationMs,
            lastStatusCode: latestEntry.statusCode,
            latestUri: latestEntry.uri,
          );
        })
        .toList(growable: false);

    summaries.sort((left, right) {
      final failureCompare = right.failureCount.compareTo(left.failureCount);
      if (failureCompare != 0) {
        return failureCompare;
      }
      return right.requestCount.compareTo(left.requestCount);
    });
    return summaries;
  }

  String _uriPatternFor(String rawUri) {
    final uri = Uri.tryParse(rawUri);
    final path = uri?.path;
    if (path == null || path.isEmpty) {
      return rawUri;
    }
    return path;
  }

  static Future<void> _defaultTickHandler(Duration duration) {
    return Future<void>.delayed(duration);
  }
}

final class _CockpitObservedHttpClient implements HttpClient {
  _CockpitObservedHttpClient(this._delegate, {required this.observer});

  final HttpClient _delegate;
  final CockpitHttpNetworkObserver observer;

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    final pending = _CockpitPendingNetworkRecord(
      requestId: observer.nextRequestId(),
      method: method,
      uri: url,
    );
    observer.markRequestStarted();
    try {
      final request = await _delegate.openUrl(method, url);
      return _CockpitObservedHttpClientRequest(
        request,
        observer: observer,
        pending: pending,
      );
    } on Object catch (error) {
      pending.error = error.toString();
      observer._finish(pending);
      rethrow;
    }
  }

  @override
  Future<HttpClientRequest> getUrl(Uri url) => openUrl('GET', url);

  @override
  Future<HttpClientRequest> postUrl(Uri url) => openUrl('POST', url);

  @override
  Future<HttpClientRequest> putUrl(Uri url) => openUrl('PUT', url);

  @override
  Future<HttpClientRequest> patchUrl(Uri url) => openUrl('PATCH', url);

  @override
  Future<HttpClientRequest> deleteUrl(Uri url) => openUrl('DELETE', url);

  @override
  Future<HttpClientRequest> headUrl(Uri url) => openUrl('HEAD', url);

  @override
  set autoUncompress(bool value) => _delegate.autoUncompress = value;

  @override
  bool get autoUncompress => _delegate.autoUncompress;

  @override
  set userAgent(String? value) => _delegate.userAgent = value;

  @override
  String? get userAgent => _delegate.userAgent;

  @override
  set idleTimeout(Duration value) => _delegate.idleTimeout = value;

  @override
  Duration get idleTimeout => _delegate.idleTimeout;

  @override
  set connectionTimeout(Duration? value) => _delegate.connectionTimeout = value;

  @override
  Duration? get connectionTimeout => _delegate.connectionTimeout;

  @override
  set maxConnectionsPerHost(int? value) =>
      _delegate.maxConnectionsPerHost = value;

  @override
  int? get maxConnectionsPerHost => _delegate.maxConnectionsPerHost;

  @override
  set authenticate(
    Future<bool> Function(Uri url, String scheme, String? realm)? f,
  ) => _delegate.authenticate = f;

  @override
  set authenticateProxy(
    Future<bool> Function(String host, int port, String scheme, String? realm)?
    f,
  ) => _delegate.authenticateProxy = f;

  @override
  set badCertificateCallback(
    bool Function(X509Certificate cert, String host, int port)? callback,
  ) => _delegate.badCertificateCallback = callback;

  @override
  set findProxy(String Function(Uri url)? f) => _delegate.findProxy = f;

  @override
  void addCredentials(
    Uri url,
    String realm,
    HttpClientCredentials credentials,
  ) => _delegate.addCredentials(url, realm, credentials);

  @override
  void addProxyCredentials(
    String host,
    int port,
    String realm,
    HttpClientCredentials credentials,
  ) => _delegate.addProxyCredentials(host, port, realm, credentials);

  @override
  void close({bool force = false}) => _delegate.close(force: force);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _CockpitObservedHttpClientRequest implements HttpClientRequest {
  _CockpitObservedHttpClientRequest(
    this._delegate, {
    required this.observer,
    required this.pending,
  });

  final HttpClientRequest _delegate;
  final CockpitHttpNetworkObserver observer;
  final _CockpitPendingNetworkRecord pending;

  @override
  HttpHeaders get headers => _delegate.headers;

  @override
  String get method => _delegate.method;

  @override
  Uri get uri => _delegate.uri;

  @override
  Encoding get encoding => _delegate.encoding;

  @override
  set encoding(Encoding value) => _delegate.encoding = value;

  @override
  bool get followRedirects => _delegate.followRedirects;

  @override
  set followRedirects(bool value) => _delegate.followRedirects = value;

  @override
  int get maxRedirects => _delegate.maxRedirects;

  @override
  set maxRedirects(int value) => _delegate.maxRedirects = value;

  @override
  bool get persistentConnection => _delegate.persistentConnection;

  @override
  set persistentConnection(bool value) =>
      _delegate.persistentConnection = value;

  @override
  int get contentLength => _delegate.contentLength;

  @override
  set contentLength(int value) => _delegate.contentLength = value;

  @override
  List<Cookie> get cookies => _delegate.cookies;

  @override
  Future<HttpClientResponse> get done => _delegate.done;

  @override
  void add(List<int> data) {
    pending.captureRequestBytes(data, observer);
    _delegate.add(data);
  }

  @override
  void write(Object? object) {
    final bytes = encoding.encode('${object ?? ''}');
    pending.captureRequestBytes(bytes, observer);
    _delegate.write(object);
  }

  @override
  void writeAll(Iterable<Object?> objects, [String separator = '']) {
    final buffer = StringBuffer();
    var isFirst = true;
    for (final object in objects) {
      if (!isFirst) {
        buffer.write(separator);
      }
      buffer.write(object ?? '');
      isFirst = false;
    }
    final bytes = encoding.encode(buffer.toString());
    pending.captureRequestBytes(bytes, observer);
    _delegate.writeAll(objects, separator);
  }

  @override
  void writeCharCode(int charCode) {
    pending.captureRequestBytes(
      encoding.encode(String.fromCharCode(charCode)),
      observer,
    );
    _delegate.writeCharCode(charCode);
  }

  @override
  void writeln([Object? object = '']) {
    final bytes = encoding.encode('${object ?? ''}\n');
    pending.captureRequestBytes(bytes, observer);
    _delegate.writeln(object);
  }

  @override
  Future<void> addStream(Stream<List<int>> stream) {
    return _delegate.addStream(
      stream.map((chunk) {
        pending.captureRequestBytes(chunk, observer);
        return chunk;
      }),
    );
  }

  @override
  Future<void> flush() => _delegate.flush();

  @override
  void abort([Object? exception, StackTrace? stackTrace]) {
    pending.error = exception?.toString() ?? 'Request aborted.';
    pending.captureRequestHeaders(observer.snapshotHeaders(_delegate.headers));
    observer._finish(pending);
    _delegate.abort(exception, stackTrace);
  }

  @override
  Future<HttpClientResponse> close() async {
    pending.captureRequestHeaders(observer.snapshotHeaders(_delegate.headers));
    try {
      final response = await _delegate.close();
      if (response.contentLength == 0 || method == 'HEAD') {
        pending.statusCode = response.statusCode;
        pending.captureResponseHeaders(
          observer.snapshotHeaders(response.headers),
        );
        observer._finish(pending);
        return _CockpitObservedHttpClientResponse(
          response,
          observer: observer,
          pending: pending,
          alreadyCompleted: true,
        );
      }
      return _CockpitObservedHttpClientResponse(
        response,
        observer: observer,
        pending: pending,
      );
    } on Object catch (error) {
      pending.error = error.toString();
      observer._finish(pending);
      rethrow;
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _CockpitObservedHttpClientResponse extends Stream<List<int>>
    implements HttpClientResponse {
  _CockpitObservedHttpClientResponse(
    this._delegate, {
    required this.observer,
    required this.pending,
    bool alreadyCompleted = false,
  }) : _completed = alreadyCompleted;

  final HttpClientResponse _delegate;
  final CockpitHttpNetworkObserver observer;
  final _CockpitPendingNetworkRecord pending;
  bool _completed;

  @override
  X509Certificate? get certificate => _delegate.certificate;

  @override
  HttpClientResponseCompressionState get compressionState =>
      _delegate.compressionState;

  @override
  int get contentLength => _delegate.contentLength;

  @override
  List<Cookie> get cookies => _delegate.cookies;

  @override
  HttpHeaders get headers => _delegate.headers;

  @override
  bool get isRedirect => _delegate.isRedirect;

  @override
  bool get persistentConnection => _delegate.persistentConnection;

  @override
  String get reasonPhrase => _delegate.reasonPhrase;

  @override
  List<RedirectInfo> get redirects => _delegate.redirects;

  @override
  int get statusCode => _delegate.statusCode;

  @override
  Future<HttpClientResponse> redirect([
    String? method,
    Uri? url,
    bool? followLoops,
  ]) => _delegate.redirect(method, url, followLoops ?? false);

  @override
  Future<Socket> detachSocket() => _delegate.detachSocket();

  @override
  HttpConnectionInfo? get connectionInfo => _delegate.connectionInfo;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return _delegate.listen(
      (chunk) {
        pending.captureResponseBytes(chunk, observer);
        onData?.call(chunk);
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!_completed) {
          _completed = true;
          pending.statusCode = _delegate.statusCode;
          pending.captureResponseHeaders(
            observer.snapshotHeaders(_delegate.headers),
          );
          pending.error = error.toString();
          observer._finish(pending);
        }
        if (onError case final handler?) {
          Function.apply(handler, <Object?>[error, stackTrace]);
        }
      },
      onDone: () {
        if (!_completed) {
          _completed = true;
          pending.statusCode = _delegate.statusCode;
          pending.captureResponseHeaders(
            observer.snapshotHeaders(_delegate.headers),
          );
          observer._finish(pending);
        }
        onDone?.call();
      },
      cancelOnError: cancelOnError,
    );
  }

  @override
  Future<E> drain<E>([E? futureValue]) async {
    await listen(null).asFuture<void>();
    return futureValue as E;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _CockpitPendingNetworkRecord {
  _CockpitPendingNetworkRecord({
    required this.requestId,
    required this.method,
    required this.uri,
  }) : startedAt = DateTime.now().toUtc();

  final String requestId;
  final String method;
  final Uri uri;
  final DateTime startedAt;
  final BytesBuilder _requestBytes = BytesBuilder(copy: false);
  final BytesBuilder _responseBytes = BytesBuilder(copy: false);
  Map<String, String> requestHeaders = const <String, String>{};
  Map<String, String> responseHeaders = const <String, String>{};
  int? statusCode;
  String? error;
  bool requestTruncated = false;
  bool responseTruncated = false;
  int requestBodyBytes = 0;
  int responseBodyBytes = 0;

  void captureRequestHeaders(Map<String, String> headers) {
    requestHeaders = headers;
  }

  void captureResponseHeaders(Map<String, String> headers) {
    responseHeaders = headers;
  }

  void captureRequestBytes(
    List<int> bytes,
    CockpitHttpNetworkObserver observer,
  ) {
    requestBodyBytes += bytes.length;
    if (!observer.captureBodies || requestTruncated) {
      return;
    }
    final remaining = observer.maxBodyBytes - _requestBytes.length;
    if (remaining <= 0) {
      requestTruncated = true;
      return;
    }
    if (bytes.length > remaining) {
      _requestBytes.add(bytes.take(remaining).toList(growable: false));
      requestTruncated = true;
      return;
    }
    _requestBytes.add(bytes);
  }

  void captureResponseBytes(
    List<int> bytes,
    CockpitHttpNetworkObserver observer,
  ) {
    responseBodyBytes += bytes.length;
    if (!observer.captureBodies || responseTruncated) {
      return;
    }
    final remaining = observer.maxBodyBytes - _responseBytes.length;
    if (remaining <= 0) {
      responseTruncated = true;
      return;
    }
    if (bytes.length > remaining) {
      _responseBytes.add(bytes.take(remaining).toList(growable: false));
      responseTruncated = true;
      return;
    }
    _responseBytes.add(bytes);
  }

  CockpitNetworkEntry buildEntry(CockpitHttpNetworkObserver observer) {
    return CockpitNetworkEntry(
      requestId: requestId,
      method: method,
      uri: uri.toString(),
      startedAt: startedAt,
      durationMs: DateTime.now().toUtc().difference(startedAt).inMilliseconds,
      statusCode: statusCode,
      requestHeaders: requestHeaders,
      responseHeaders: responseHeaders,
      requestBodyPreview: observer.previewBytes(_requestBytes.takeBytes()),
      responseBodyPreview: observer.previewBytes(_responseBytes.takeBytes()),
      requestBodyBytes: requestBodyBytes,
      responseBodyBytes: responseBodyBytes,
      requestBodyTruncated: requestTruncated,
      responseBodyTruncated: responseTruncated,
      error: error,
    );
  }
}
