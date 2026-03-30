export 'core/cockpit_mcp_feature_category.dart';
export 'core/cockpit_mcp_feature_configuration.dart';
export 'core/cockpit_mcp_tool_annotations.dart';
export 'core/cockpit_mcp_tool_definition.dart';

import '../application/cockpit_application_service_exception.dart';
import '../development/cockpit_development_probe.dart';
import '../development/cockpit_development_session_handle.dart';
import '../session/cockpit_remote_session_handle.dart';
import 'cockpit_mcp_error.dart';
import 'core/cockpit_mcp_feature_category.dart';
import 'core/cockpit_mcp_tool_annotations.dart';
import 'core/cockpit_mcp_tool_definition.dart';

abstract base class CockpitMcpTool {
  String get name;
  String get description;
  Map<String, Object?> get inputSchema;
  CockpitMcpToolAnnotations get annotations =>
      CockpitMcpToolAnnotations.defaults;
  List<CockpitMcpFeatureCategory> get categories =>
      const <CockpitMcpFeatureCategory>[CockpitMcpFeatureCategory.all];
  bool get enabledByDefault => true;

  CockpitMcpToolDefinition get definition => CockpitMcpToolDefinition(
        name: name,
        description: description,
        inputSchema: inputSchema,
        annotations: annotations,
        categories: categories,
        enabledByDefault: enabledByDefault,
      );

  Future<Map<String, Object?>> call(Map<String, Object?> arguments);

  Map<String, Object?> toDescriptor() => definition.toDescriptor();
}

String cockpitReadRequiredString(Map<String, Object?> arguments, String key) {
  final value = arguments[key];
  if (value is String && value.isNotEmpty) {
    return value;
  }
  throw CockpitMcpError.invalidArguments(
    'Missing required string argument.',
    details: <String, Object?>{'argument': key},
  );
}

String? cockpitReadOptionalString(Map<String, Object?> arguments, String key) {
  final value = arguments[key];
  if (value == null) {
    return null;
  }
  if (value is String && value.isNotEmpty) {
    return value;
  }
  throw CockpitMcpError.invalidArguments(
    'Argument must be a non-empty string.',
    details: <String, Object?>{'argument': key},
  );
}

int cockpitReadRequiredInt(Map<String, Object?> arguments, String key) {
  final value = arguments[key];
  final parsed = _readInt(value);
  if (parsed != null) {
    return parsed;
  }
  throw CockpitMcpError.invalidArguments(
    'Missing required integer argument.',
    details: <String, Object?>{'argument': key},
  );
}

int? cockpitReadOptionalInt(Map<String, Object?> arguments, String key) {
  final value = arguments[key];
  if (value == null) {
    return null;
  }
  final parsed = _readInt(value);
  if (parsed != null) {
    return parsed;
  }
  throw CockpitMcpError.invalidArguments(
    'Argument must be an integer.',
    details: <String, Object?>{'argument': key},
  );
}

bool? cockpitReadOptionalBool(Map<String, Object?> arguments, String key) {
  final value = arguments[key];
  if (value == null) {
    return null;
  }
  if (value is bool) {
    return value;
  }
  throw CockpitMcpError.invalidArguments(
    'Argument must be a boolean.',
    details: <String, Object?>{'argument': key},
  );
}

Map<String, Object?> cockpitReadRequiredObject(
  Map<String, Object?> arguments,
  String key,
) {
  final value = arguments[key];
  if (value is Map<Object?, Object?>) {
    return Map<String, Object?>.from(value);
  }
  throw CockpitMcpError.invalidArguments(
    'Missing required object argument.',
    details: <String, Object?>{'argument': key},
  );
}

Map<String, Object?>? cockpitReadOptionalObject(
  Map<String, Object?> arguments,
  String key,
) {
  final value = arguments[key];
  if (value == null) {
    return null;
  }
  if (value is Map<Object?, Object?>) {
    return Map<String, Object?>.from(value);
  }
  throw CockpitMcpError.invalidArguments(
    'Argument must be an object.',
    details: <String, Object?>{'argument': key},
  );
}

List<Map<String, Object?>> cockpitReadRequiredObjectList(
  Map<String, Object?> arguments,
  String key,
) {
  final value = arguments[key];
  if (value is! List<Object?>) {
    throw CockpitMcpError.invalidArguments(
      'Missing required object-list argument.',
      details: <String, Object?>{'argument': key},
    );
  }
  return value.map((item) {
    if (item is! Map<Object?, Object?>) {
      throw CockpitMcpError.invalidArguments(
        'List argument must contain only objects.',
        details: <String, Object?>{'argument': key},
      );
    }
    return Map<String, Object?>.from(item);
  }).toList(growable: false);
}

CockpitRemoteSessionHandle? cockpitReadOptionalSessionHandle(
  Map<String, Object?> arguments,
) {
  final value = cockpitReadOptionalObject(arguments, 'session_handle');
  if (value == null) {
    return null;
  }
  try {
    return CockpitRemoteSessionHandle.fromJson(value);
  } on Object {
    throw CockpitMcpError.invalidArguments(
      'session_handle is invalid JSON.',
      details: <String, Object?>{'argument': 'session_handle'},
    );
  }
}

CockpitDevelopmentSessionHandle? cockpitReadOptionalDevelopmentSessionHandle(
  Map<String, Object?> arguments,
) {
  final value = cockpitReadOptionalObject(arguments, 'session_handle');
  if (value == null) {
    return null;
  }
  try {
    return CockpitDevelopmentSessionHandle.fromJson(value);
  } on Object {
    throw CockpitMcpError.invalidArguments(
      'session_handle is invalid development session JSON.',
      details: <String, Object?>{'argument': 'session_handle'},
    );
  }
}

CockpitDevelopmentProbe? cockpitReadOptionalDevelopmentProbe(
  Map<String, Object?> arguments,
  String key,
) {
  final value = cockpitReadOptionalObject(arguments, key);
  if (value == null) {
    return null;
  }
  try {
    return CockpitDevelopmentProbe.fromJson(value);
  } on Object {
    throw CockpitMcpError.invalidArguments(
      '$key is invalid development probe JSON.',
      details: <String, Object?>{'argument': key},
    );
  }
}

Map<String, Object?> cockpitMcpResult({
  required String text,
  required Map<String, Object?> structuredContent,
}) {
  return <String, Object?>{
    'content': <Map<String, Object?>>[
      <String, Object?>{'type': 'text', 'text': text},
    ],
    'structuredContent': structuredContent,
  };
}

Never cockpitRethrowAsMcpError(Object error) {
  if (error is CockpitMcpError) {
    throw error;
  }
  if (error is CockpitApplicationServiceException) {
    throw CockpitMcpError.fromService(error);
  }
  if (error is FormatException) {
    throw CockpitMcpError.invalidArguments(error.message);
  }
  throw CockpitMcpError.internal(
    'Unexpected MCP tool failure.',
    details: <String, Object?>{'error': error.toString()},
  );
}

int? _readInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value);
  }
  return null;
}
