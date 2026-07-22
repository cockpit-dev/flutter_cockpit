import 'cockpit_worker_value_reader.dart';

sealed class CockpitJsonRpcMessage {
  const CockpitJsonRpcMessage();

  String get jsonrpc => '2.0';

  Map<String, Object?> toJson();

  static CockpitJsonRpcMessage fromJson(Object? value) {
    final json = workerObject(value, r'$');
    if (json['jsonrpc'] != '2.0') {
      throw const FormatException('Unsupported JSON-RPC version.');
    }
    if (json.containsKey('method')) {
      return CockpitJsonRpcRequest.fromJson(json);
    }
    if (json.containsKey('result') || json.containsKey('error')) {
      return CockpitJsonRpcResponse.fromJson(json);
    }
    throw const FormatException('Invalid JSON-RPC message shape.');
  }
}

final class CockpitJsonRpcRequest extends CockpitJsonRpcMessage {
  CockpitJsonRpcRequest({
    required this.id,
    required this.method,
    required Map<String, Object?> params,
  }) : params = Map<String, Object?>.unmodifiable(params) {
    workerId(id, r'$.id');
    workerMethodName(method, r'$.method');
    workerValidateJsonValue(this.params, r'$.params');
  }

  final String id;
  final String method;
  final Map<String, Object?> params;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'jsonrpc': jsonrpc,
    'id': id,
    'method': method,
    'params': params,
  };

  factory CockpitJsonRpcRequest.fromJson(Map<String, Object?> json) {
    workerKeys(
      json,
      const <String>{'jsonrpc', 'id', 'method', 'params'},
      r'$',
      required: const <String>{'jsonrpc', 'id', 'method', 'params'},
    );
    return CockpitJsonRpcRequest(
      id: workerId(json['id'], r'$.id'),
      method: workerMethodName(json['method'], r'$.method'),
      params: workerObject(json['params'], r'$.params'),
    );
  }
}

final class CockpitJsonRpcResponse extends CockpitJsonRpcMessage {
  CockpitJsonRpcResponse.success({required this.id, this.result})
    : error = null {
    workerId(id, r'$.id');
    workerValidateJsonValue(result, r'$.result');
  }

  CockpitJsonRpcResponse.failure({required this.id, required this.error})
    : result = null {
    workerId(id, r'$.id');
  }

  final String id;
  final Object? result;
  final CockpitJsonRpcError? error;

  bool get isSuccess => error == null;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'jsonrpc': jsonrpc,
    'id': id,
    if (error == null) 'result': result else 'error': error!.toJson(),
  };

  factory CockpitJsonRpcResponse.fromJson(Map<String, Object?> json) {
    workerKeys(
      json,
      const <String>{'jsonrpc', 'id', 'result', 'error'},
      r'$',
      required: const <String>{'jsonrpc', 'id'},
    );
    final hasResult = json.containsKey('result');
    final hasError = json.containsKey('error');
    if (hasResult == hasError) {
      throw const FormatException(
        'JSON-RPC response must contain exactly one result or error.',
      );
    }
    final id = workerId(json['id'], r'$.id');
    return hasResult
        ? CockpitJsonRpcResponse.success(id: id, result: json['result'])
        : CockpitJsonRpcResponse.failure(
            id: id,
            error: CockpitJsonRpcError.fromJson(json['error']),
          );
  }
}

final class CockpitJsonRpcError {
  CockpitJsonRpcError({
    required this.code,
    required this.message,
    required this.workerCode,
    Map<String, Object?> details = const <String, Object?>{},
  }) : details = Map<String, Object?>.unmodifiable(details) {
    if (code > -32000 || code < -32768) {
      throw const FormatException('JSON-RPC error code is invalid.');
    }
    workerString(message, r'$.message', maximum: 1024);
    workerId(workerCode, r'$.data.code');
    workerValidateJsonValue(this.details, r'$.data.details');
  }

  final int code;
  final String message;
  final String workerCode;
  final Map<String, Object?> details;

  Map<String, Object?> toJson() => <String, Object?>{
    'code': code,
    'message': message,
    'data': <String, Object?>{'code': workerCode, 'details': details},
  };

  factory CockpitJsonRpcError.fromJson(Object? value) {
    final json = workerObject(value, r'$.error');
    workerKeys(
      json,
      const <String>{'code', 'message', 'data'},
      r'$.error',
      required: const <String>{'code', 'message', 'data'},
    );
    final data = workerObject(json['data'], r'$.error.data');
    workerKeys(
      data,
      const <String>{'code', 'details'},
      r'$.error.data',
      required: const <String>{'code', 'details'},
    );
    return CockpitJsonRpcError(
      code: workerInteger(
        json['code'],
        r'$.error.code',
        minimum: -32768,
        maximum: -32000,
      ),
      message: workerString(json['message'], r'$.error.message'),
      workerCode: workerId(data['code'], r'$.error.data.code'),
      details: workerObject(data['details'], r'$.error.data.details'),
    );
  }
}
