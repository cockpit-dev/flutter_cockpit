import 'package:args/args.dart';
import 'package:args/command_runner.dart';

import '../session/cockpit_flutter_launch_configuration.dart';

void cockpitAddFlutterLaunchConfigurationOptions(ArgParser parser) {
  parser
    ..addMultiOption(
      'dart-define',
      help:
          'Repeatable Flutter --dart-define KEY=VALUE. Reserved FLUTTER_COCKPIT_* keys are managed by cockpit.',
      splitCommas: false,
    )
    ..addMultiOption(
      'dart-define-from-file',
      help: 'Repeatable Flutter --dart-define-from-file path.',
      splitCommas: false,
    )
    ..addMultiOption(
      'flutter-arg',
      help:
          'Repeatable raw Flutter tool argument for uncommon launch flags. Use structured flags for dart defines.',
      splitCommas: false,
    )
    ..addMultiOption(
      'env',
      help:
          'Repeatable child-process environment override as KEY=VALUE. Values may be empty.',
      splitCommas: false,
    );
}

CockpitFlutterLaunchConfiguration cockpitReadFlutterLaunchConfiguration(
  ArgResults? argResults,
  String usage,
) {
  try {
    return CockpitFlutterLaunchConfiguration(
      dartDefines: _readMultiOption(argResults, 'dart-define'),
      dartDefineFromFiles: _readMultiOption(
        argResults,
        'dart-define-from-file',
      ),
      flutterArgs: _readFlutterArgs(argResults),
      environment: _readEnvironment(argResults),
    );
  } on ArgumentError catch (error) {
    throw UsageException(error.message, usage);
  }
}

List<String> _readMultiOption(ArgResults? argResults, String name) {
  return (argResults?[name] as List<String>?) ?? const <String>[];
}

List<String> _readFlutterArgs(ArgResults? argResults) {
  return <String>[
    for (final entry in _readMultiOption(argResults, 'flutter-arg'))
      ...cockpitParseFlutterArgumentString(entry),
  ];
}

Map<String, String> _readEnvironment(ArgResults? argResults) {
  final entries = _readMultiOption(argResults, 'env');
  final environment = <String, String>{};
  for (final entry in entries) {
    final separatorIndex = entry.indexOf('=');
    if (separatorIndex <= 0) {
      throw ArgumentError.value(
        entry,
        'env',
        'Entries must use KEY=VALUE syntax.',
      );
    }
    environment[entry.substring(0, separatorIndex)] = entry.substring(
      separatorIndex + 1,
    );
  }
  return environment;
}
