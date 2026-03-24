import 'package:collection/collection.dart';

final class CockpitNetworkEntry {
  const CockpitNetworkEntry({
    required this.requestId,
    required this.method,
    required this.uri,
    required this.startedAt,
    required this.durationMs,
    this.statusCode,
    this.requestHeaders = const <String, String>{},
    this.responseHeaders = const <String, String>{},
    this.requestBodyPreview,
    this.responseBodyPreview,
    this.requestBodyBytes = 0,
    this.responseBodyBytes = 0,
    this.requestBodyTruncated = false,
    this.responseBodyTruncated = false,
    this.error,
  });

  final String requestId;
  final String method;
  final String uri;
  final DateTime startedAt;
  final int durationMs;
  final int? statusCode;
  final Map<String, String> requestHeaders;
  final Map<String, String> responseHeaders;
  final String? requestBodyPreview;
  final String? responseBodyPreview;
  final int requestBodyBytes;
  final int responseBodyBytes;
  final bool requestBodyTruncated;
  final bool responseBodyTruncated;
  final String? error;

  bool get isFailure =>
      error != null || (statusCode != null && statusCode! >= 400);

  static const MapEquality<String, String> _mapEquality =
      MapEquality<String, String>();

  Map<String, Object?> toJson() => <String, Object?>{
        'requestId': requestId,
        'method': method,
        'uri': uri,
        'startedAt': startedAt.toUtc().toIso8601String(),
        'durationMs': durationMs,
        'statusCode': statusCode,
        'requestHeaders': requestHeaders,
        'responseHeaders': responseHeaders,
        'requestBodyPreview': requestBodyPreview,
        'responseBodyPreview': responseBodyPreview,
        'requestBodyBytes': requestBodyBytes,
        'responseBodyBytes': responseBodyBytes,
        'requestBodyTruncated': requestBodyTruncated,
        'responseBodyTruncated': responseBodyTruncated,
        'error': error,
      };

  factory CockpitNetworkEntry.fromJson(Map<String, Object?> json) {
    return CockpitNetworkEntry(
      requestId: json['requestId']! as String,
      method: json['method']! as String,
      uri: json['uri']! as String,
      startedAt: DateTime.parse(json['startedAt']! as String).toUtc(),
      durationMs: json['durationMs'] as int? ?? 0,
      statusCode: json['statusCode'] as int?,
      requestHeaders: Map<String, String>.from(
        (json['requestHeaders'] as Map<Object?, Object?>?) ??
            const <Object?, Object?>{},
      ),
      responseHeaders: Map<String, String>.from(
        (json['responseHeaders'] as Map<Object?, Object?>?) ??
            const <Object?, Object?>{},
      ),
      requestBodyPreview: json['requestBodyPreview'] as String?,
      responseBodyPreview: json['responseBodyPreview'] as String?,
      requestBodyBytes: json['requestBodyBytes'] as int? ?? 0,
      responseBodyBytes: json['responseBodyBytes'] as int? ?? 0,
      requestBodyTruncated: json['requestBodyTruncated'] as bool? ?? false,
      responseBodyTruncated: json['responseBodyTruncated'] as bool? ?? false,
      error: json['error'] as String?,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CockpitNetworkEntry &&
            other.requestId == requestId &&
            other.method == method &&
            other.uri == uri &&
            other.startedAt == startedAt &&
            other.durationMs == durationMs &&
            other.statusCode == statusCode &&
            _mapEquality.equals(other.requestHeaders, requestHeaders) &&
            _mapEquality.equals(other.responseHeaders, responseHeaders) &&
            other.requestBodyPreview == requestBodyPreview &&
            other.responseBodyPreview == responseBodyPreview &&
            other.requestBodyBytes == requestBodyBytes &&
            other.responseBodyBytes == responseBodyBytes &&
            other.requestBodyTruncated == requestBodyTruncated &&
            other.responseBodyTruncated == responseBodyTruncated &&
            other.error == error;
  }

  @override
  int get hashCode => Object.hash(
        requestId,
        method,
        uri,
        startedAt,
        durationMs,
        statusCode,
        _mapEquality.hash(requestHeaders),
        _mapEquality.hash(responseHeaders),
        requestBodyPreview,
        responseBodyPreview,
        requestBodyBytes,
        responseBodyBytes,
        requestBodyTruncated,
        responseBodyTruncated,
        error,
      );
}
