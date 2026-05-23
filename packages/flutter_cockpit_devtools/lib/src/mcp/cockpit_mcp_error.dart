import '../application/cockpit_application_service_exception.dart';

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

  factory CockpitMcpError.fromService(
    CockpitApplicationServiceException error,
  ) {
    return CockpitMcpError(
      code: _serviceCodeToMcpCode(error.code),
      message: error.message,
      data: <String, Object?>{
        'serviceCode': error.code,
        if (error.details.isNotEmpty) 'details': error.details,
      },
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'code': code,
    'message': message,
    if (data.isNotEmpty) 'data': data,
  };

  static int _serviceCodeToMcpCode(String code) {
    switch (code) {
      case 'missingSessionReference':
      case 'sessionHandleNotFound':
      case 'invalidSessionHandleJson':
      case 'invalidBundleJson':
      case 'bundleFileMissing':
        return -32602;
      default:
        return -32000;
    }
  }
}
