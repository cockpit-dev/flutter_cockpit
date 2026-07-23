final class CockpitMcpError implements Exception {
  const CockpitMcpError({
    required this.code,
    required this.message,
    this.data = const <String, Object?>{},
  });

  final int code;
  final String message;
  final Map<String, Object?> data;

  factory CockpitMcpError.invalidArguments(
    String message, {
    Map<String, Object?> details = const <String, Object?>{},
  }) {
    return CockpitMcpError(code: -32602, message: message, data: details);
  }

  factory CockpitMcpError.methodNotFound(String method) {
    return CockpitMcpError(
      code: -32601,
      message: 'Unsupported MCP method: $method',
      data: <String, Object?>{'method': method},
    );
  }

  factory CockpitMcpError.internal(
    String message, {
    Map<String, Object?> details = const <String, Object?>{},
  }) {
    return CockpitMcpError(code: -32000, message: message, data: details);
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'code': code,
    'message': message,
    if (data.isNotEmpty) 'data': data,
  };
}
