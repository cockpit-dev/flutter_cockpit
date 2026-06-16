import 'dart:io';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import 'cockpit_interactive_cli_support.dart';

void cockpitAddWorkspaceRootOption(
  ArgParser parser, {
  String optionName = 'workspace-root',
  String help =
      'Workspace root used for package_config, pubspec lookup, and process execution. Defaults to the current directory.',
}) {
  parser.addOption(optionName, help: help);
}

void cockpitAddParentDirectoryOption(
  ArgParser parser, {
  String optionName = 'parent-directory',
  String help =
      'Parent directory where the project should be created. Defaults to the current directory.',
}) {
  parser.addOption(optionName, help: help);
}

String cockpitReadWorkspaceRoot(
  ArgResults? argResults, {
  String optionName = 'workspace-root',
}) {
  return _readDirectoryOption(argResults, optionName: optionName);
}

String cockpitReadParentDirectory(
  ArgResults? argResults, {
  String optionName = 'parent-directory',
}) {
  return _readDirectoryOption(argResults, optionName: optionName);
}

String cockpitReadRequiredStringOption(
  ArgResults? argResults,
  String optionName,
  String usage,
) {
  final value = cockpitReadOptionalStringOption(argResults, optionName);
  if (value == null) {
    throw UsageException('--$optionName is required.', usage);
  }
  return value;
}

String? cockpitReadOptionalStringOption(
  ArgResults? argResults,
  String optionName,
) {
  final value = argResults?[optionName] as String?;
  if (value == null || value.isEmpty) {
    return null;
  }
  return value;
}

int cockpitReadRequiredIntOption(
  ArgResults? argResults,
  String optionName,
  String usage,
) {
  final value = cockpitReadOptionalIntOption(argResults, optionName, usage);
  if (value == null) {
    throw UsageException('--$optionName is required.', usage);
  }
  return value;
}

int? cockpitReadOptionalIntOption(
  ArgResults? argResults,
  String optionName,
  String usage,
) {
  final value = cockpitReadOptionalStringOption(argResults, optionName);
  if (value == null) {
    return null;
  }
  final parsed = int.tryParse(value);
  if (parsed != null) {
    return parsed;
  }
  throw UsageException('--$optionName must be an integer.', usage);
}

int cockpitReadRequiredPositiveIntOption(
  ArgResults? argResults,
  String optionName,
  String usage,
) {
  final value = cockpitReadRequiredIntOption(argResults, optionName, usage);
  if (value > 0) {
    return value;
  }
  throw UsageException('--$optionName must be a positive integer.', usage);
}

int? cockpitReadOptionalPositiveIntOption(
  ArgResults? argResults,
  String optionName,
  String usage,
) {
  final value = cockpitReadOptionalIntOption(argResults, optionName, usage);
  if (value == null) {
    return null;
  }
  if (value > 0) {
    return value;
  }
  throw UsageException('--$optionName must be a positive integer.', usage);
}

List<String> cockpitReadMultiStringOption(
  ArgResults? argResults,
  String optionName,
) {
  final values = argResults?.multiOption(optionName) ?? const <String>[];
  return List<String>.unmodifiable(values.where((value) => value.isNotEmpty));
}

Future<void> cockpitWriteWorkspacePayload({
  required Object payload,
  required ArgResults? argResults,
  required StringSink stdoutSink,
}) {
  return cockpitWriteJsonPayload(
    payload: payload,
    argResults: argResults,
    stdoutSink: stdoutSink,
  );
}

String _readDirectoryOption(
  ArgResults? argResults, {
  required String optionName,
}) {
  final value = cockpitReadOptionalStringOption(argResults, optionName);
  if (value == null) {
    return p.normalize(Directory.current.path);
  }
  return p.normalize(value);
}
