import '../session/cockpit_flutter_launch_configuration.dart';
import 'cockpit_mcp_error.dart';
import 'cockpit_mcp_tool.dart';

const Map<String, Object?>
cockpitFlutterLaunchConfigurationMcpProperties = <String, Object?>{
  'dartDefines': <String, Object?>{
    'type': 'array',
    'items': <String, Object?>{'type': 'string'},
    'description':
        'Repeatable Flutter dart defines as KEY=VALUE. FLUTTER_COCKPIT_* keys are reserved.',
  },
  'dartDefineFromFiles': <String, Object?>{
    'type': 'array',
    'items': <String, Object?>{'type': 'string'},
    'description': 'Repeatable Flutter --dart-define-from-file paths.',
  },
  'flutterArgs': <String, Object?>{
    'type': 'array',
    'items': <String, Object?>{'type': 'string'},
    'description':
        'Raw Flutter tool arguments for uncommon launch flags. Use dartDefines for dart-define flags.',
  },
  'environment': <String, Object?>{
    'type': 'object',
    'additionalProperties': <String, Object?>{'type': 'string'},
    'description':
        'Child-process environment overrides. Values are not persisted in app/session handles.',
  },
};

CockpitFlutterLaunchConfiguration cockpitReadMcpFlutterLaunchConfiguration(
  Map<String, Object?> arguments,
) {
  try {
    return CockpitFlutterLaunchConfiguration(
      dartDefines: _readStringList(arguments, 'dartDefines'),
      dartDefineFromFiles: _readStringList(arguments, 'dartDefineFromFiles'),
      flutterArgs: _readStringList(arguments, 'flutterArgs'),
      environment: _readStringEnvironment(arguments),
    );
  } on ArgumentError catch (error) {
    throw CockpitMcpError.invalidArguments(
      error.message,
      details: <String, Object?>{'argument': error.name},
    );
  }
}

List<String> _readStringList(Map<String, Object?> arguments, String key) {
  final value = arguments[key];
  if (value == null) {
    return const <String>[];
  }
  if (value is! List<Object?>) {
    throw CockpitMcpError.invalidArguments(
      '$key must be a string array.',
      details: <String, Object?>{'argument': key},
    );
  }
  return <String>[
    for (var index = 0; index < value.length; index++)
      if (value[index] case final String item)
        item
      else
        throw CockpitMcpError.invalidArguments(
          '$key must contain only strings.',
          details: <String, Object?>{'argument': key, 'index': index},
        ),
  ];
}

Map<String, String> _readStringEnvironment(Map<String, Object?> arguments) {
  final object = cockpitReadOptionalObject(arguments, 'environment');
  if (object == null) {
    return const <String, String>{};
  }
  final result = <String, String>{};
  for (final entry in object.entries) {
    final value = entry.value;
    if (value is! String) {
      throw CockpitMcpError.invalidArguments(
        'environment values must be strings.',
        details: <String, Object?>{'argument': 'environment'},
      );
    }
    result[entry.key] = value;
  }
  return result;
}
