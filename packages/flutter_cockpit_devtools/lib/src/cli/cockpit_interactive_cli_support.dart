import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';

import '../application/cockpit_compact_json.dart';
import '../application/cockpit_interactive_result_profile.dart';

void cockpitAddRemoteSessionArgs(ArgParser parser) {
  parser
    ..addOption(
      'base-url',
      help:
          'Base URL for the running app session. Use this when you do not have session-json.',
    )
    ..addOption(
      'session-json',
      help:
          'Recommended session handle JSON file emitted by launch-remote-session.',
    )
    ..addOption(
      'android-device-id',
      help:
          'Android device ID for adb port forwarding when the app is not directly reachable.',
    )
    ..addOption(
      'output-json',
      help:
          'Write JSON to a file instead of stdout. Prefer this for larger results.',
    );
}

void cockpitAddAppArgs(ArgParser parser) {
  parser
    ..addOption(
      'base-url',
      help:
          'Base URL for the running app. Use this when you do not have app-json.',
    )
    ..addOption(
      'app-json',
      help: 'Recommended app handle JSON file emitted by launch-app.',
    )
    ..addOption(
      'android-device-id',
      help:
          'Android device ID for adb port forwarding when the app is not directly reachable.',
    )
    ..addOption(
      'output-json',
      help:
          'Write JSON to a file instead of stdout. Prefer this for larger results.',
    );
}

void cockpitRequireRemoteSessionReference(
  ArgResults? argResults,
  String usage,
) {
  final sessionJsonPath = argResults?['session-json'] as String?;
  final baseUrl = argResults?['base-url'] as String?;
  if ((sessionJsonPath == null || sessionJsonPath.isEmpty) &&
      (baseUrl == null || baseUrl.isEmpty)) {
    throw UsageException(
      '--base-url is required when --session-json is not provided.',
      usage,
    );
  }
}

void cockpitRequireAppReference(ArgResults? argResults, String usage) {
  final appJsonPath = argResults?['app-json'] as String?;
  final baseUrl = argResults?['base-url'] as String?;
  if ((appJsonPath == null || appJsonPath.isEmpty) &&
      (baseUrl == null || baseUrl.isEmpty)) {
    throw UsageException(
      '--base-url is required when --app-json is not provided.',
      usage,
    );
  }
}

void cockpitAddProfileArg(
  ArgParser parser, {
  String optionName = 'profile',
  CockpitInteractiveResultProfileName defaultProfile =
      CockpitInteractiveResultProfileName.standard,
}) {
  parser.addOption(
    optionName,
    allowed: CockpitInteractiveResultProfileName.values
        .map((profile) => profile.jsonValue)
        .toList(growable: false),
    defaultsTo: defaultProfile.jsonValue,
    help:
        'Result layer: minimal=core only, standard=core plus small UI, inspect=summary plus failures and delta, evidence=full diagnostics and snapshot.',
  );
}

void cockpitAddSnapshotOptionsArgs(
  ArgParser parser, {
  String inlineOption = 'snapshot-options-json',
  String fileOption = 'snapshot-options-file',
}) {
  parser
    ..addOption(
      inlineOption,
      help: 'Inline JSON that overrides snapshot detail or collection limits.',
    )
    ..addOption(
      fileOption,
      help:
          'Path to a JSON file with snapshot detail or collection limit overrides.',
    );
}

void cockpitAddCompareAgainstSnapshotRefArg(
  ArgParser parser, {
  String optionName = 'compare-against-snapshot-ref',
}) {
  parser.addOption(
    optionName,
    help:
        'Existing snapshotRef to diff against instead of reading only the latest state.',
  );
}

void cockpitAddCommandJsonArgs(ArgParser parser) {
  parser
    ..addOption(
      'command-json',
      help:
          'Inline JSON object for one command. Prefer --command-file when the payload is large.',
    )
    ..addOption(
      'command-file',
      help: 'Path to a JSON file for one command object.',
    );
}

void cockpitAddCommandsJsonArgs(ArgParser parser) {
  parser
    ..addOption(
      'commands-json',
      help:
          'Inline JSON array of commands. Prefer --commands-file when the payload is large.',
    )
    ..addOption(
      'commands-file',
      help: 'Path to a JSON file with a command array.',
    );
}

void cockpitAddCommandTimeoutArg(
  ArgParser parser, {
  String optionName = 'timeout-ms',
  String help =
      'Default command timeout in milliseconds. Applied only when a command does not already set timeoutMs.',
}) {
  parser.addOption(optionName, help: help);
}

void cockpitAddRecordingArgs(
  ArgParser parser, {
  String inlineOption = 'recording-json',
  String fileOption = 'recording-file',
}) {
  parser
    ..addOption(
      inlineOption,
      help: 'Inline JSON object that describes the recording request.',
    )
    ..addOption(
      fileOption,
      help: 'Path to a JSON file that describes the recording request.',
    );
}

CockpitInteractiveResultProfile cockpitReadResultProfile(
  ArgResults? argResults, {
  String optionName = 'profile',
  CockpitInteractiveResultProfileName defaultProfile =
      CockpitInteractiveResultProfileName.standard,
}) {
  final value = argResults?[optionName];
  return CockpitInteractiveResultProfile.preset(
    value == null
        ? defaultProfile
        : CockpitInteractiveResultProfileName.fromJson(value),
  );
}

Future<Map<String, Object?>> cockpitReadRequiredJsonObject({
  required ArgResults? argResults,
  required String inlineOption,
  required String fileOption,
  required String label,
  required String usage,
}) async {
  final decoded = await _readJsonValue(
    argResults: argResults,
    inlineOption: inlineOption,
    fileOption: fileOption,
    label: label,
    usage: usage,
    requiredInput: true,
  );
  if (decoded is! Map<Object?, Object?>) {
    throw UsageException('$label must decode to a JSON object.', usage);
  }
  return Map<String, Object?>.from(decoded);
}

Future<Map<String, Object?>?> cockpitReadOptionalJsonObject({
  required ArgResults? argResults,
  required String inlineOption,
  required String fileOption,
  required String label,
  required String usage,
}) async {
  final decoded = await _readJsonValue(
    argResults: argResults,
    inlineOption: inlineOption,
    fileOption: fileOption,
    label: label,
    usage: usage,
    requiredInput: false,
  );
  if (decoded == null) {
    return null;
  }
  if (decoded is! Map<Object?, Object?>) {
    throw UsageException('$label must decode to a JSON object.', usage);
  }
  return Map<String, Object?>.from(decoded);
}

Future<List<Map<String, Object?>>> cockpitReadRequiredJsonObjectList({
  required ArgResults? argResults,
  required String inlineOption,
  required String fileOption,
  required String label,
  required String usage,
}) async {
  final decoded = await _readJsonValue(
    argResults: argResults,
    inlineOption: inlineOption,
    fileOption: fileOption,
    label: label,
    usage: usage,
    requiredInput: true,
  );
  if (decoded is! List<Object?>) {
    throw UsageException('$label must decode to a JSON array.', usage);
  }
  return decoded
      .map((item) => Map<String, Object?>.from(item! as Map<Object?, Object?>))
      .toList(growable: false);
}

Future<void> cockpitWriteJsonPayload({
  required Object payload,
  required ArgResults? argResults,
  required StringSink stdoutSink,
}) async {
  final renderedPayload = _renderJsonPayload(payload);
  final outputJson = argResults?['output-json'] as String?;
  if (outputJson == null || outputJson.isEmpty) {
    stdoutSink.writeln(renderedPayload);
    return;
  }

  final outputFile = File(outputJson);
  await outputFile.parent.create(recursive: true);
  await outputFile.writeAsString(renderedPayload);
}

Uri? cockpitReadOptionalBaseUri(ArgResults? argResults) {
  final baseUrl = argResults?['base-url'] as String?;
  if (baseUrl == null || baseUrl.isEmpty) {
    return null;
  }
  return Uri.parse(baseUrl);
}

int? cockpitReadOptionalInt(ArgResults? argResults, String optionName) {
  final value = argResults?[optionName] as String?;
  if (value == null || value.isEmpty) {
    return null;
  }
  return int.parse(value);
}

Future<Object?> _readJsonValue({
  required ArgResults? argResults,
  required String inlineOption,
  required String fileOption,
  required String label,
  required String usage,
  required bool requiredInput,
}) async {
  final inlineValue = argResults?[inlineOption] as String?;
  final filePath = argResults?[fileOption] as String?;
  final hasInline = inlineValue != null && inlineValue.isNotEmpty;
  final hasFile = filePath != null && filePath.isNotEmpty;
  if (hasInline && hasFile) {
    throw UsageException(
      'Use only one of --$inlineOption or --$fileOption for $label.',
      usage,
    );
  }
  if (!hasInline && !hasFile) {
    if (!requiredInput) {
      return null;
    }
    throw UsageException(
      '$label requires --$inlineOption or --$fileOption.',
      usage,
    );
  }

  final source = hasInline ? inlineValue : await File(filePath!).readAsString();
  return jsonDecode(source);
}

String _renderJsonPayload(Object payload) {
  if (payload is! String) {
    return cockpitPrettyJsonText(payload);
  }

  final trimmed = payload.trimLeft();
  if (!trimmed.startsWith('{') && !trimmed.startsWith('[')) {
    return payload;
  }

  try {
    return cockpitPrettyJsonText(jsonDecode(payload));
  } on FormatException {
    return payload;
  }
}
