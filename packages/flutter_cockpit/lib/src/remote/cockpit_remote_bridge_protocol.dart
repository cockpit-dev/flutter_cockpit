import 'dart:async';
import 'dart:convert';

import 'cockpit_remote_session_endpoint_handler.dart';

typedef CockpitRemoteBridgeBinaryFileReader =
    FutureOr<List<int>> Function(String sourceFilePath);

final class CockpitRemoteBridgeRequest {
  const CockpitRemoteBridgeRequest({
    required this.requestId,
    required this.method,
    required this.path,
    this.jsonBody,
  });

  final String requestId;
  final String method;
  final String path;
  final Map<String, Object?>? jsonBody;

  Uri get uri => Uri.parse(path);

  Map<String, Object?> toJson() => <String, Object?>{
    'requestId': requestId,
    'method': method,
    'path': path,
    if (jsonBody != null) 'jsonBody': jsonBody,
  };

  factory CockpitRemoteBridgeRequest.fromJson(Map<String, Object?> json) {
    final jsonBody = json['jsonBody'];
    final requestId = json['requestId'];
    final method = json['method'];
    final path = json['path'];
    if (requestId is! String || requestId.isEmpty) {
      throw const FormatException(
        'Bridge request field "requestId" must be a non-empty string.',
      );
    }
    if (method is! String || method.isEmpty) {
      throw const FormatException(
        'Bridge request field "method" must be a non-empty string.',
      );
    }
    if (path is! String || path.isEmpty) {
      throw const FormatException(
        'Bridge request field "path" must be a non-empty string.',
      );
    }
    if (jsonBody != null && jsonBody is! Map<Object?, Object?>) {
      throw const FormatException(
        'Bridge request field "jsonBody" must be a JSON object.',
      );
    }
    return CockpitRemoteBridgeRequest(
      requestId: requestId,
      method: method,
      path: path,
      jsonBody: jsonBody == null
          ? null
          : Map<String, Object?>.from(jsonBody as Map<Object?, Object?>),
    );
  }
}

final class CockpitRemoteBridgeResponse {
  const CockpitRemoteBridgeResponse({
    required this.requestId,
    required this.statusCode,
    this.contentType = 'application/json',
    this.jsonBody,
    this.bytesBase64,
  });

  final String requestId;
  final int statusCode;
  final String contentType;
  final Map<String, Object?>? jsonBody;
  final String? bytesBase64;

  List<int>? get binaryBody =>
      bytesBase64 == null ? null : base64Decode(bytesBase64!);

  Map<String, Object?> toJson() => <String, Object?>{
    'requestId': requestId,
    'statusCode': statusCode,
    'contentType': contentType,
    if (jsonBody != null) 'jsonBody': jsonBody,
    if (bytesBase64 != null) 'bytesBase64': bytesBase64,
  };

  factory CockpitRemoteBridgeResponse.fromJson(Map<String, Object?> json) {
    final jsonBody = json['jsonBody'];
    final requestId = json['requestId'];
    final statusCode = json['statusCode'];
    final contentType = json['contentType'];
    final bytesBase64 = json['bytesBase64'];
    if (requestId is! String || requestId.isEmpty) {
      throw const FormatException(
        'Bridge response field "requestId" must be a non-empty string.',
      );
    }
    if (statusCode is! int) {
      throw const FormatException(
        'Bridge response field "statusCode" must be an integer.',
      );
    }
    if (statusCode < 100 || statusCode > 599) {
      throw const FormatException(
        'Bridge response field "statusCode" must be an HTTP status code from 100 to 599.',
      );
    }
    if (contentType != null && contentType is! String) {
      throw const FormatException(
        'Bridge response field "contentType" must be a string.',
      );
    }
    if (jsonBody != null && jsonBody is! Map<Object?, Object?>) {
      throw const FormatException(
        'Bridge response field "jsonBody" must be a JSON object.',
      );
    }
    if (bytesBase64 != null && bytesBase64 is! String) {
      throw const FormatException(
        'Bridge response field "bytesBase64" must be a string.',
      );
    }
    if (jsonBody != null && bytesBase64 != null) {
      throw const FormatException(
        'Bridge response must not contain both "jsonBody" and "bytesBase64".',
      );
    }
    return CockpitRemoteBridgeResponse(
      requestId: requestId,
      statusCode: statusCode,
      contentType: contentType as String? ?? 'application/json',
      jsonBody: jsonBody == null
          ? null
          : Map<String, Object?>.from(jsonBody as Map<Object?, Object?>),
      bytesBase64: bytesBase64 as String?,
    );
  }

  factory CockpitRemoteBridgeResponse.fromEndpointResponse({
    required String requestId,
    required CockpitRemoteSessionEndpointResponse response,
  }) {
    return CockpitRemoteBridgeResponse(
      requestId: requestId,
      statusCode: response.statusCode,
      contentType: response.contentType,
      jsonBody: response.jsonBody,
      bytesBase64: response.binaryBody == null
          ? null
          : base64Encode(response.binaryBody!),
    );
  }
}

typedef CockpitRemoteSessionEndpointRequestHandler =
    Future<CockpitRemoteSessionEndpointResponse> Function(
      CockpitRemoteSessionEndpointRequest request,
    );

final class CockpitRemoteSessionBridgeProtocol {
  const CockpitRemoteSessionBridgeProtocol({
    required CockpitRemoteSessionEndpointRequestHandler requestHandler,
    CockpitRemoteBridgeBinaryFileReader? binaryFileReader,
  }) : _requestHandler = requestHandler,
       _binaryFileReader = binaryFileReader;

  final CockpitRemoteSessionEndpointRequestHandler _requestHandler;
  final CockpitRemoteBridgeBinaryFileReader? _binaryFileReader;

  Future<String> handleRawMessage(String message) async {
    var requestId = 'unknown';
    try {
      final decoded = jsonDecode(message);
      if (decoded is! Map<Object?, Object?>) {
        return _encodeBridgeError(
          requestId: requestId,
          statusCode: 400,
          error: 'bridgeInvalidMessage',
          message: 'Bridge message payload must be a JSON object.',
        );
      }
      final requestJson = Map<String, Object?>.from(decoded);
      final rawRequestId = requestJson['requestId'];
      if (rawRequestId is String && rawRequestId.isNotEmpty) {
        requestId = rawRequestId;
      }

      final request = CockpitRemoteBridgeRequest.fromJson(requestJson);
      requestId = request.requestId;
      final endpointResponse = await _requestHandler(
        CockpitRemoteSessionEndpointRequest(
          method: request.method,
          uri: request.uri,
          jsonBody: request.jsonBody ?? const <String, Object?>{},
        ),
      );
      return jsonEncode(
        (await _bridgeResponseFromEndpointResponse(
          requestId: requestId,
          response: endpointResponse,
        )).toJson(),
      );
    } on FormatException catch (error) {
      return _encodeBridgeError(
        requestId: requestId,
        statusCode: 400,
        error: 'bridgeInvalidMessage',
        message: error.message,
      );
    } on Object catch (error) {
      return _encodeBridgeError(
        requestId: requestId,
        statusCode: 500,
        error: 'bridgeRequestFailed',
        message: '$error',
      );
    }
  }

  Future<CockpitRemoteBridgeResponse> _bridgeResponseFromEndpointResponse({
    required String requestId,
    required CockpitRemoteSessionEndpointResponse response,
  }) async {
    final sourceFilePath = response.sourceFilePath;
    if (sourceFilePath == null) {
      return CockpitRemoteBridgeResponse.fromEndpointResponse(
        requestId: requestId,
        response: response,
      );
    }

    final reader = _binaryFileReader;
    if (reader == null) {
      return CockpitRemoteBridgeResponse(
        requestId: requestId,
        statusCode: 500,
        jsonBody: const <String, Object?>{
          'error': 'bridgeBinaryFileUnsupported',
          'message':
              'The bridge cannot serialize a file-backed endpoint response without a binary file reader.',
        },
      );
    }

    late final List<int> bytes;
    try {
      bytes = await Future<List<int>>.value(reader(sourceFilePath));
    } on Object catch (error) {
      return CockpitRemoteBridgeResponse(
        requestId: requestId,
        statusCode: 500,
        jsonBody: <String, Object?>{
          'error': 'bridgeBinaryFileReadFailed',
          'message':
              'The bridge could not read a file-backed response: '
              '$error',
        },
      );
    }
    return CockpitRemoteBridgeResponse(
      requestId: requestId,
      statusCode: response.statusCode,
      contentType: response.contentType,
      bytesBase64: base64Encode(bytes),
    );
  }

  String _encodeBridgeError({
    required String requestId,
    required int statusCode,
    required String error,
    required String message,
  }) {
    return jsonEncode(
      CockpitRemoteBridgeResponse(
        requestId: requestId,
        statusCode: statusCode,
        jsonBody: <String, Object?>{'error': error, 'message': message},
      ).toJson(),
    );
  }
}
