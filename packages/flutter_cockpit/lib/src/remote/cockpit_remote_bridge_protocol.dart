import 'dart:convert';

import 'cockpit_remote_session_endpoint_handler.dart';

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
    return CockpitRemoteBridgeRequest(
      requestId: json['requestId']! as String,
      method: json['method']! as String,
      path: json['path']! as String,
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
    return CockpitRemoteBridgeResponse(
      requestId: json['requestId']! as String,
      statusCode: json['statusCode']! as int,
      contentType: json['contentType'] as String? ?? 'application/json',
      jsonBody: jsonBody == null
          ? null
          : Map<String, Object?>.from(jsonBody as Map<Object?, Object?>),
      bytesBase64: json['bytesBase64'] as String?,
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

typedef CockpitRemoteSessionEndpointRequestHandler
    = Future<CockpitRemoteSessionEndpointResponse> Function(
  CockpitRemoteSessionEndpointRequest request,
);

final class CockpitRemoteSessionBridgeProtocol {
  const CockpitRemoteSessionBridgeProtocol({
    required CockpitRemoteSessionEndpointRequestHandler requestHandler,
  }) : _requestHandler = requestHandler;

  final CockpitRemoteSessionEndpointRequestHandler _requestHandler;

  Future<String> handleRawMessage(String message) async {
    final decoded = jsonDecode(message);
    if (decoded is! Map<Object?, Object?>) {
      throw const FormatException('Bridge message payload must be an object.');
    }
    final request = CockpitRemoteBridgeRequest.fromJson(
      Map<String, Object?>.from(decoded),
    );
    final endpointResponse = await _requestHandler(
      CockpitRemoteSessionEndpointRequest(
        method: request.method,
        uri: request.uri,
        jsonBody: request.jsonBody ?? const <String, Object?>{},
      ),
    );
    return jsonEncode(
      CockpitRemoteBridgeResponse.fromEndpointResponse(
        requestId: request.requestId,
        response: endpointResponse,
      ).toJson(),
    );
  }
}
