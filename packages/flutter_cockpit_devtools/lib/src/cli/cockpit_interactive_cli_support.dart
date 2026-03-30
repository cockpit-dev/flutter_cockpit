import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';

import '../application/cockpit_interactive_result_profile.dart';

void cockpitAddRemoteSessionArgs(ArgParser parser) {
  parser
    ..addOption('base-url', help: 'Base URL for the running app session.')
    ..addOption(
      'session-json',
      help:
          'Optional session handle JSON file emitted by launch-remote-session.',
    )
    ..addOption(
      'android-device-id',
      help: 'Optional Android device ID used to set up adb port forwarding.',
    )
    ..addOption(
      'output-json',
      help: 'Optional file path where the command result should be written.',
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
  required String payload,
  required ArgResults? argResults,
  required StringSink stdoutSink,
}) async {
  final outputJson = argResults?['output-json'] as String?;
  if (outputJson == null || outputJson.isEmpty) {
    stdoutSink.writeln(payload);
    return;
  }

  final outputFile = File(outputJson);
  await outputFile.parent.create(recursive: true);
  await outputFile.writeAsString(payload);
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
