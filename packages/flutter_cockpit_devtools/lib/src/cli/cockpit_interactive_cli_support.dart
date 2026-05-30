import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../application/cockpit_compact_json.dart';
import '../application/cockpit_interactive_result_profile.dart';

const String cockpitDefaultAppHandleRelativePath =
    '.dart_tool/flutter_cockpit/latest_app.json';
const String cockpitDefaultTargetHandleRelativePath =
    '.dart_tool/flutter_cockpit/latest_target.json';
const String cockpitDefaultRemoteSessionHandleRelativePath =
    '.dart_tool/flutter_cockpit/latest_remote_session.json';
const String cockpitDefaultDevelopmentSessionHandleRelativePath =
    '.dart_tool/flutter_cockpit/latest_development_session.json';

const String cockpitAppJsonOptionHelp =
    'App handle JSON emitted by launch-app. If omitted, the CLI reuses '
    '$cockpitDefaultAppHandleRelativePath when it exists in the current workspace.';
const String cockpitTargetJsonOptionHelp =
    'Target handle JSON emitted by launch-target. If omitted, target-scoped commands reuse '
    '$cockpitDefaultTargetHandleRelativePath when it exists in the current workspace.';
const String cockpitRemoteSessionJsonOptionHelp =
    'Remote session handle JSON emitted by launch-remote-session. If omitted, remote-scoped '
    'commands reuse $cockpitDefaultRemoteSessionHandleRelativePath when it exists in the current workspace.';
const String cockpitDevelopmentSessionJsonOptionHelp =
    'Development session handle JSON emitted by launch-development-session. If omitted, '
    'development-session commands reuse $cockpitDefaultDevelopmentSessionHandleRelativePath when it exists in the current workspace.';

const String cockpitOutputOptionHelp =
    'Write the command payload to a file. Default stdout then prints only the '
    'output path; use --output-format to choose the file format.';

const String cockpitOutputFormatOptionHelp =
    'File output format for --output. ai is the default full semantic render; '
    'json writes pretty JSON for structured follow-up reads.';

const List<String> cockpitCliStdoutFormatValues = <String>[
  'auto',
  'ai',
  'json',
  'path',
  'none',
];

const List<String> cockpitCliFileOutputFormatValues = <String>['ai', 'json'];

void cockpitAddOutputArgs(ArgParser parser) {
  if (!parser.options.containsKey('stdout-format')) {
    parser.addOption(
      'stdout-format',
      allowed: cockpitCliStdoutFormatValues,
      defaultsTo: 'auto',
      help:
          'Terminal output format. auto writes AI-readable full output unless a file output is requested, then writes only file paths. Use json for jq pipelines.',
    );
  }
  if (!parser.options.containsKey('output')) {
    parser.addOption('output', help: cockpitOutputOptionHelp);
  }
  if (!parser.options.containsKey('output-format')) {
    parser.addOption(
      'output-format',
      allowed: cockpitCliFileOutputFormatValues,
      defaultsTo: 'ai',
      help: cockpitOutputFormatOptionHelp,
    );
  }
}

void cockpitAddRemoteSessionArgs(ArgParser parser) {
  parser
    ..addOption(
      'base-url',
      help:
          'Base URL for the running app session. Use this when you do not have session-json.',
    )
    ..addOption('session-json', help: cockpitRemoteSessionJsonOptionHelp)
    ..addOption(
      'android-device-id',
      help:
          'Android device ID for adb port forwarding when the app is not directly reachable.',
    );
  cockpitAddOutputArgs(parser);
}

void cockpitAddAppArgs(ArgParser parser) {
  parser
    ..addOption(
      'base-url',
      help:
          'Base URL for the running app. When used with app-json, this overrides only the current connection address and keeps app metadata from the handle.',
    )
    ..addOption('app-json', help: cockpitAppJsonOptionHelp)
    ..addOption(
      'android-device-id',
      help:
          'Android device ID for adb port forwarding when the app is not directly reachable.',
    );
  cockpitAddOutputArgs(parser);
}

void cockpitRequireRemoteSessionReference(
  ArgResults? argResults,
  String usage,
) {
  final sessionJsonPath = cockpitResolveRemoteSessionHandlePath(argResults);
  final baseUrl = argResults?['base-url'] as String?;
  if ((sessionJsonPath == null || sessionJsonPath.isEmpty) &&
      (baseUrl == null || baseUrl.isEmpty)) {
    throw UsageException(
      '--base-url is required when --session-json is not provided and '
      '${cockpitDefaultRemoteSessionHandlePath()} does not exist.',
      usage,
    );
  }
}

void cockpitRequireAppReference(ArgResults? argResults, String usage) {
  final appJsonPath = cockpitResolveAppHandlePath(argResults);
  final baseUrl = argResults?['base-url'] as String?;
  if ((appJsonPath == null || appJsonPath.isEmpty) &&
      (baseUrl == null || baseUrl.isEmpty)) {
    throw UsageException(
      '--base-url is required when --app-json is not provided and '
      '${cockpitDefaultAppHandlePath()} does not exist.',
      usage,
    );
  }
}

String cockpitDefaultAppHandlePath([String? workingDirectory]) {
  return _cockpitDefaultHandlePath(
    cockpitDefaultAppHandleRelativePath,
    workingDirectory,
  );
}

String cockpitDefaultTargetHandlePath([String? workingDirectory]) {
  return _cockpitDefaultHandlePath(
    cockpitDefaultTargetHandleRelativePath,
    workingDirectory,
  );
}

String cockpitDefaultRemoteSessionHandlePath([String? workingDirectory]) {
  return _cockpitDefaultHandlePath(
    cockpitDefaultRemoteSessionHandleRelativePath,
    workingDirectory,
  );
}

String cockpitDefaultDevelopmentSessionHandlePath([String? workingDirectory]) {
  return _cockpitDefaultHandlePath(
    cockpitDefaultDevelopmentSessionHandleRelativePath,
    workingDirectory,
  );
}

String _cockpitDefaultHandlePath(
  String relativePath,
  String? workingDirectory,
) {
  return p.normalize(
    p.join(workingDirectory ?? Directory.current.path, relativePath),
  );
}

String? cockpitResolveAppHandlePath(
  ArgResults? argResults, {
  String? workingDirectory,
}) {
  final explicit = argResults?['app-json'] as String?;
  if (explicit != null && explicit.isNotEmpty) {
    return explicit;
  }

  final hasBaseUrlOption =
      argResults != null && argResults.options.contains('base-url');
  final explicitBaseUrl = hasBaseUrlOption
      ? argResults['base-url'] as String?
      : null;
  if (explicitBaseUrl != null && explicitBaseUrl.isNotEmpty) {
    return null;
  }

  final defaultPath = cockpitDefaultAppHandlePath(workingDirectory);
  if (File(defaultPath).existsSync()) {
    return defaultPath;
  }
  return null;
}

String? cockpitResolveTargetHandlePath(
  ArgResults? argResults, {
  String? workingDirectory,
}) {
  final explicit = _readOptionIfDefined(argResults, 'target-json');
  if (explicit != null && explicit.isNotEmpty) {
    return explicit;
  }
  if (_hasExplicitOptionValue(argResults, 'base-url') ||
      _hasExplicitOptionValue(argResults, 'app-json')) {
    return null;
  }

  final defaultPath = cockpitDefaultTargetHandlePath(workingDirectory);
  if (File(defaultPath).existsSync()) {
    return defaultPath;
  }
  return null;
}

String? cockpitResolveRemoteSessionHandlePath(
  ArgResults? argResults, {
  String? workingDirectory,
}) {
  final explicit = _readOptionIfDefined(argResults, 'session-json');
  if (explicit != null && explicit.isNotEmpty) {
    return explicit;
  }
  if (_hasExplicitOptionValue(argResults, 'base-url')) {
    return null;
  }

  final defaultPath = cockpitDefaultRemoteSessionHandlePath(workingDirectory);
  if (File(defaultPath).existsSync()) {
    return defaultPath;
  }
  return null;
}

String? cockpitResolveDevelopmentSessionHandlePath(
  ArgResults? argResults, {
  String? workingDirectory,
}) {
  final explicit = _readOptionIfDefined(argResults, 'session-json');
  if (explicit != null && explicit.isNotEmpty) {
    return explicit;
  }

  final defaultPath = cockpitDefaultDevelopmentSessionHandlePath(
    workingDirectory,
  );
  if (File(defaultPath).existsSync()) {
    return defaultPath;
  }
  return null;
}

String cockpitRequireResolvedAppHandlePath(
  ArgResults? argResults,
  String usage,
) {
  final resolved = cockpitResolveAppHandlePath(argResults);
  if (resolved != null && resolved.isNotEmpty) {
    return resolved;
  }
  throw UsageException(
    '--app-json is required unless ${cockpitDefaultAppHandlePath()} already exists.',
    usage,
  );
}

String cockpitRequireResolvedTargetHandlePath(
  ArgResults? argResults,
  String usage,
) {
  final resolved = cockpitResolveTargetHandlePath(argResults);
  if (resolved != null && resolved.isNotEmpty) {
    return resolved;
  }
  throw UsageException(
    '--target-json is required unless ${cockpitDefaultTargetHandlePath()} already exists.',
    usage,
  );
}

String cockpitRequireResolvedDevelopmentSessionHandlePath(
  ArgResults? argResults,
  String usage,
) {
  final resolved = cockpitResolveDevelopmentSessionHandlePath(argResults);
  if (resolved != null && resolved.isNotEmpty) {
    return resolved;
  }
  throw UsageException(
    '--session-json is required unless ${cockpitDefaultDevelopmentSessionHandlePath()} already exists.',
    usage,
  );
}

String cockpitReadProjectDirOption(ArgResults? argResults) {
  final explicit = _readOptionIfDefined(argResults, 'project-dir');
  if (explicit != null && explicit.isNotEmpty) {
    return p.normalize(explicit);
  }
  return p.normalize(Directory.current.path);
}

String cockpitReadLaunchPlatform(
  ArgResults? argResults,
  String usage, {
  Set<String> allowedPlatforms = const <String>{
    'android',
    'ios',
    'macos',
    'windows',
    'linux',
    'web',
  },
}) {
  final explicit = _readOptionIfDefined(argResults, 'platform');
  final platform = explicit == null || explicit.isEmpty
      ? _defaultHostLaunchPlatform()
      : explicit;
  if (platform != null && allowedPlatforms.contains(platform)) {
    return platform;
  }
  throw UsageException(
    '--platform is required on this host. Allowed values: ${allowedPlatforms.join(', ')}.',
    usage,
  );
}

String? _defaultHostLaunchPlatform() {
  if (Platform.isMacOS) {
    return 'macos';
  }
  if (Platform.isWindows) {
    return 'windows';
  }
  if (Platform.isLinux) {
    return 'linux';
  }
  return null;
}

bool _hasExplicitOptionValue(ArgResults? argResults, String name) {
  final value = _readOptionIfDefined(argResults, name);
  return value != null && value.isNotEmpty;
}

String? _readOptionIfDefined(ArgResults? argResults, String name) {
  if (argResults == null || !argResults.options.contains(name)) {
    return null;
  }
  return argResults[name] as String?;
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
  return <Map<String, Object?>>[
    for (var index = 0; index < decoded.length; index++)
      if (decoded[index] case final Map<Object?, Object?> item)
        Map<String, Object?>.from(item)
      else
        throw UsageException(
          '$label item at index $index must decode to a JSON object.',
          usage,
        ),
  ];
}

Future<void> cockpitWriteJsonPayload({
  String? commandName,
  required Object payload,
  required ArgResults? argResults,
  required StringSink stdoutSink,
}) async {
  final effectiveCommandName = commandName ?? argResults?.name ?? 'command';
  final outputPaths = <String, String>{};
  final output = _readOptionalOutputOption(argResults, 'output');
  if (output != null && output.isNotEmpty) {
    final outputFile = File(output);
    await outputFile.parent.create(recursive: true);
    final outputFormat = _effectiveOutputFormat(argResults);
    if (outputFormat == 'json') {
      await outputFile.writeAsString(_renderJsonPayload(payload, pretty: true));
    } else {
      await outputFile.writeAsString(
        cockpitRenderAiPayload(
          commandName: effectiveCommandName,
          payload: payload,
        ),
      );
    }
    outputPaths['output'] = outputFile.path;
  }

  final stdoutFormat = _effectiveStdoutFormat(
    argResults,
    hasFileOutputs: outputPaths.isNotEmpty,
  );
  switch (stdoutFormat) {
    case 'none':
      return;
    case 'path':
      for (final entry in outputPaths.entries) {
        stdoutSink.writeln('${entry.key}=${entry.value}');
      }
      return;
    case 'json':
      stdoutSink.writeln(_renderJsonPayload(payload, pretty: false));
      return;
    case 'ai':
      stdoutSink.writeln(
        cockpitRenderAiPayload(
          commandName: effectiveCommandName,
          payload: payload,
        ),
      );
      return;
    default:
      stdoutSink.writeln(
        cockpitRenderAiPayload(
          commandName: effectiveCommandName,
          payload: payload,
        ),
      );
  }
}

String _effectiveOutputFormat(ArgResults? argResults) {
  if (argResults == null || !argResults.options.contains('output-format')) {
    return 'ai';
  }
  return argResults['output-format'] as String? ?? 'ai';
}

String? _readOptionalOutputOption(ArgResults? argResults, String name) {
  if (argResults == null || !argResults.options.contains(name)) {
    return null;
  }
  final value = argResults[name] as String?;
  if (value == null || value.isEmpty) {
    return null;
  }
  return value;
}

String _effectiveStdoutFormat(
  ArgResults? argResults, {
  required bool hasFileOutputs,
}) {
  final raw = argResults != null && argResults.options.contains('stdout-format')
      ? argResults['stdout-format'] as String? ?? 'auto'
      : 'auto';
  if (raw != 'auto') {
    return raw;
  }
  return hasFileOutputs ? 'path' : 'ai';
}

Uri? cockpitReadOptionalBaseUri(ArgResults? argResults) {
  final baseUrl = argResults?['base-url'] as String?;
  if (baseUrl == null || baseUrl.isEmpty) {
    return null;
  }
  return Uri.parse(baseUrl);
}

int? cockpitReadOptionalInt(
  ArgResults? argResults,
  String optionName,
  String usage,
) {
  final value = argResults?[optionName] as String?;
  if (value == null || value.isEmpty) {
    return null;
  }
  final parsed = int.tryParse(value);
  if (parsed != null) {
    return parsed;
  }
  throw UsageException('--$optionName must be an integer.', usage);
}

int? cockpitReadOptionalPositiveInt(
  ArgResults? argResults,
  String optionName,
  String usage,
) {
  final value = cockpitReadOptionalInt(argResults, optionName, usage);
  if (value == null) {
    return null;
  }
  if (value > 0) {
    return value;
  }
  throw UsageException('--$optionName must be a positive integer.', usage);
}

int? cockpitReadOptionalHttpStatusCode(
  ArgResults? argResults,
  String optionName,
  String usage,
) {
  final value = cockpitReadOptionalInt(argResults, optionName, usage);
  if (value == null) {
    return null;
  }
  if (value >= 100 && value <= 599) {
    return value;
  }
  throw UsageException(
    '--$optionName must be an HTTP status code from 100 to 599.',
    usage,
  );
}

int cockpitReadRequiredPortOption(
  ArgResults? argResults,
  String optionName,
  String usage,
) {
  final value = cockpitReadOptionalInt(argResults, optionName, usage);
  if (value != null && value > 0 && value <= 65535) {
    return value;
  }
  throw UsageException(
    '--$optionName must be a TCP port from 1 to 65535.',
    usage,
  );
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

String _renderJsonPayload(Object payload, {required bool pretty}) {
  if (payload is! String) {
    return pretty
        ? cockpitPrettyJsonText(payload)
        : cockpitCompactJsonText(payload);
  }

  final trimmed = payload.trimLeft();
  if (!trimmed.startsWith('{') && !trimmed.startsWith('[')) {
    return payload;
  }

  try {
    final decoded = jsonDecode(payload);
    return pretty
        ? cockpitPrettyJsonText(decoded)
        : cockpitCompactJsonText(decoded);
  } on FormatException {
    return payload;
  }
}

String cockpitRenderAiPayload({
  required String commandName,
  required Object payload,
}) {
  final decoded = _decodePayloadForRendering(payload);
  final buffer = StringBuffer()
    ..writeln('cockpit.v=1')
    ..writeln('command=$commandName')
    ..writeln('status=${_aiStatusFor(decoded)}');
  final next =
      _readString(decoded, 'recommendedNextStep') ??
      _readString(decoded, 'nextStep');
  if (next != null) {
    buffer.writeln('next=$next');
  }

  final stateLines = _aiStateLines(decoded);
  if (stateLines.isNotEmpty) {
    buffer.writeln();
    buffer.writeln('state');
    for (final line in stateLines) {
      buffer.writeln('  $line');
    }
  }

  final summaryLines = _aiSummaryLines(decoded);
  if (summaryLines.isNotEmpty) {
    buffer.writeln();
    buffer.writeln('summary');
    for (final line in summaryLines) {
      buffer.writeln('  $line');
    }
  }

  final resultLines = _aiResultLines(decoded);
  if (resultLines.isNotEmpty) {
    buffer.writeln();
    buffer.writeln('results');
    for (final line in resultLines) {
      buffer.writeln('  $line');
    }
  }

  final issueLines = _aiIssueLines(decoded);
  if (issueLines.isNotEmpty) {
    buffer.writeln();
    buffer.writeln('issues');
    for (final line in issueLines) {
      buffer.writeln('  $line');
    }
  }

  final artifactLines = _aiArtifactLines(decoded);
  if (artifactLines.isNotEmpty) {
    buffer.writeln();
    buffer.writeln('artifacts');
    for (final line in artifactLines) {
      buffer.writeln('  $line');
    }
  }

  final bundleLines = _aiBundleLines(decoded);
  if (bundleLines.isNotEmpty) {
    buffer.writeln();
    buffer.writeln('bundle');
    for (final line in bundleLines) {
      buffer.writeln('  $line');
    }
  }

  final refLines = _aiRefLines(decoded);
  if (refLines.isNotEmpty) {
    buffer.writeln();
    buffer.writeln('refs');
    for (final line in refLines) {
      buffer.writeln('  $line');
    }
  }

  final remainingLines = _aiRemainingLines(decoded);
  if (remainingLines.isNotEmpty) {
    buffer.writeln();
    buffer.writeln('data');
    for (final line in remainingLines) {
      buffer.writeln('  $line');
    }
  }

  return buffer.toString().trimRight();
}

Object? _decodePayloadForRendering(Object payload) {
  if (payload is! String) {
    return payload;
  }
  final trimmed = payload.trimLeft();
  if (!trimmed.startsWith('{') && !trimmed.startsWith('[')) {
    return payload;
  }
  try {
    return jsonDecode(payload);
  } on FormatException {
    return payload;
  }
}

String _aiStatusFor(Object? value) {
  if (value is Map<Object?, Object?>) {
    final explicit =
        _readString(value, 'status') ??
        _readString(value, 'classification') ??
        _readString(value, 'state');
    if (explicit != null) {
      return explicit;
    }
    final bundleSummary = _bundleSummaryMapForAi(value);
    final bundleStatus = _readNestedString(bundleSummary, const <String>[
      'manifest',
      'status',
    ]);
    if (bundleStatus != null) {
      return bundleStatus;
    }
    final command = value['command'];
    if (command is Map<Object?, Object?>) {
      final success = command['success'];
      if (success is bool) {
        return success ? 'ok' : 'failed';
      }
    }
    final summary = value['summary'];
    if (summary is Map<Object?, Object?>) {
      final failedCount = summary['failedCount'] ?? summary['failureCount'];
      if (failedCount is num && failedCount > 0) {
        return 'failed';
      }
    }
    if (value['hasErrors'] == true) {
      return 'failed';
    }
  }
  return 'ok';
}

List<String> _aiStateLines(Object? value) {
  if (value is! Map<Object?, Object?>) {
    return const <String>[];
  }
  final lines = <String>[];
  _addKeyValue(
    lines,
    'route',
    _firstString(value, const <String>[
      'currentRouteName',
      'routeName',
      'route',
    ]),
  );
  _addKeyValue(lines, 'appId', _readString(value, 'appId'));
  _addKeyValue(lines, 'sessionId', _readString(value, 'sessionId'));
  _addKeyValue(lines, 'platform', _readString(value, 'platform'));
  _addKeyValue(lines, 'transport', _readString(value, 'transportType'));
  _addKeyValue(lines, 'plane', _readString(value, 'selectedPlane'));
  _addKeyValue(lines, 'diagnosticLevel', _readString(value, 'diagnosticLevel'));
  _addKeyValue(lines, 'truncated', _readBool(value, 'truncated'));
  return lines;
}

List<String> _aiSummaryLines(Object? value) {
  if (value is! Map<Object?, Object?>) {
    return const <String>[];
  }
  final lines = <String>[];
  final uiSummary = _readMap(value, 'uiSummary');
  if (uiSummary != null) {
    _addKeyValue(
      lines,
      'visibleTargets',
      _readNumber(uiSummary, 'visibleTargetCount'),
    );
    _addKeyValue(
      lines,
      'cockpitIds',
      _readNumber(uiSummary, 'targetsWithCockpitIdCount'),
    );
    _addKeyValue(
      lines,
      'text',
      _joinPreviewList(_readList(uiSummary, 'textPreviews')),
    );
  }
  final summary = _readMap(value, 'summary');
  if (summary != null) {
    for (final key in summary.keys.whereType<String>().take(12)) {
      _addKeyValue(lines, key, summary[key]);
    }
  }
  _addKeyValue(lines, 'available', _readBool(value, 'available'));
  return lines;
}

List<String> _aiResultLines(Object? value) {
  if (value is! Map<Object?, Object?>) {
    return const <String>[];
  }
  final lines = <String>[];
  final command = _readMap(value, 'command');
  if (command != null) {
    lines.add(
      _compactInlineMap(
        command,
        preferredKeys: const <String>[
          'commandId',
          'commandType',
          'success',
          'durationMs',
          'usedCaptureFallback',
        ],
      ),
    );
  }
  final results = _readList(value, 'results');
  if (results != null) {
    for (var index = 0; index < results.length; index++) {
      final item = results[index];
      if (item is Map<Object?, Object?>) {
        final itemCommand = _readMap(item, 'command') ?? item;
        lines.add(
          '[$index] ${_compactInlineMap(itemCommand, preferredKeys: const <String>['commandId', 'commandType', 'success', 'durationMs'])}',
        );
      } else {
        lines.add('[$index] ${_formatAiScalar(item)}');
      }
    }
  }
  return lines.where((line) => line.trim().isNotEmpty).toList(growable: false);
}

List<String> _aiIssueLines(Object? value) {
  if (value is! Map<Object?, Object?>) {
    return const <String>[];
  }
  final lines = <String>[];
  final issueEvidence = _readMap(value, 'issueEvidence');
  if (issueEvidence != null) {
    _addIssueEvidenceLines(lines, issueEvidence);
  }
  final bundleIssueEvidence = _readNestedMap(value, const <String>[
    'bundleSummary',
    'issueEvidence',
  ]);
  if (bundleIssueEvidence != null && bundleIssueEvidence != issueEvidence) {
    _addIssueEvidenceLines(lines, bundleIssueEvidence);
  }
  final command = _readMap(value, 'command');
  final error = _readMap(value, 'error') ?? _readMap(command, 'error');
  if (error != null) {
    lines.add(
      _compactInlineMap(
        error,
        preferredKeys: const <String>['code', 'message', 'details'],
      ),
    );
  }
  final failures =
      _readList(value, 'validationFailures') ??
      _readList(value, 'failures') ??
      _readList(value, 'errors');
  if (failures != null) {
    for (var index = 0; index < failures.length; index++) {
      final failure = failures[index];
      if (failure is Map<Object?, Object?>) {
        lines.add(
          '[$index] ${_compactInlineMap(failure, preferredKeys: const <String>['code', 'message', 'path', 'severity'])}',
        );
      } else {
        lines.add('[$index] ${_formatAiScalar(failure)}');
      }
    }
  }
  final lastError = _readString(value, 'lastError');
  if (lastError != null) {
    lines.add('lastError=${_formatAiScalar(lastError)}');
  }
  return lines;
}

void _addIssueEvidenceLines(
  List<String> lines,
  Map<Object?, Object?> issueEvidence,
) {
  final issueKinds = _readList(issueEvidence, 'issueKinds');
  final failureSummary = _readString(issueEvidence, 'failureSummary');
  final recommendedNextStep = _readString(issueEvidence, 'recommendedNextStep');
  lines.add(
    'issueEvidence status=${_readString(issueEvidence, 'status') ?? '?'} kinds=${_joinPreviewList(issueKinds) ?? '-'} next=${recommendedNextStep ?? '-'}',
  );
  if (failureSummary != null) {
    lines.add('failureSummary=${_formatAiScalar(failureSummary)}');
  }

  final failedCommands = _readList(issueEvidence, 'failedCommands');
  if (failedCommands != null) {
    for (var index = 0; index < failedCommands.length && index < 3; index++) {
      final failedCommand = failedCommands[index];
      if (failedCommand is Map<Object?, Object?>) {
        lines.add(
          'failedCommand[$index] ${_compactInlineMap(failedCommand, preferredKeys: const <String>['commandId', 'commandType', 'errorCode', 'routeName', 'expectedRouteName', 'durationMs', 'diagnosticsArtifactPath'])}',
        );
      }
    }
  }

  final runtimeIssues = _readList(issueEvidence, 'runtimeIssues');
  if (runtimeIssues != null) {
    for (var index = 0; index < runtimeIssues.length && index < 2; index++) {
      final runtimeIssue = runtimeIssues[index];
      if (runtimeIssue is Map<Object?, Object?>) {
        lines.add(
          'runtimeIssue[$index] ${_compactInlineMap(runtimeIssue, preferredKeys: const <String>['kind', 'severity', 'message', 'routeName'])}',
        );
      }
    }
  }

  final networkIssues = _readList(issueEvidence, 'networkIssues');
  if (networkIssues != null) {
    for (var index = 0; index < networkIssues.length && index < 2; index++) {
      final networkIssue = networkIssues[index];
      if (networkIssue is Map<Object?, Object?>) {
        lines.add(
          'networkIssue[$index] ${_compactInlineMap(networkIssue, preferredKeys: const <String>['method', 'uri', 'statusCode', 'error', 'durationMs'])}',
        );
      }
    }
  }

  final artifactIssues = _readList(issueEvidence, 'artifactIssues');
  if (artifactIssues != null) {
    for (var index = 0; index < artifactIssues.length && index < 2; index++) {
      final artifactIssue = artifactIssues[index];
      if (artifactIssue is Map<Object?, Object?>) {
        lines.add(
          'artifactIssue[$index] ${_compactInlineMap(artifactIssue, preferredKeys: const <String>['code', 'path'])}',
        );
      }
    }
  }

  final gateFailures = _readList(issueEvidence, 'gateFailures');
  if (gateFailures != null) {
    for (var index = 0; index < gateFailures.length && index < 2; index++) {
      final gateFailure = gateFailures[index];
      if (gateFailure is Map<Object?, Object?>) {
        lines.add(
          'gateFailure[$index] ${_compactInlineMap(gateFailure, preferredKeys: const <String>['gate', 'failureCodes'])}',
        );
      }
    }
  }

  final evidencePaths = _readMap(issueEvidence, 'evidencePaths');
  if (evidencePaths != null) {
    final primaryScreenshotPath = _readString(
      evidencePaths,
      'primaryScreenshotPath',
    );
    final diagnosticsArtifactPaths = _readList(
      evidencePaths,
      'diagnosticsArtifactPaths',
    );
    if (primaryScreenshotPath != null ||
        (diagnosticsArtifactPaths?.isNotEmpty ?? false)) {
      lines.add(
        'evidencePaths screenshot=${primaryScreenshotPath ?? '-'} diagnostics=${_joinPreviewList(diagnosticsArtifactPaths) ?? '-'}',
      );
    }
  }
}

List<String> _aiArtifactLines(Object? value) {
  if (value is! Map<Object?, Object?>) {
    return const <String>[];
  }
  final lines = <String>[];
  final artifacts = _readList(value, 'artifacts');
  if (artifacts != null) {
    for (var index = 0; index < artifacts.length; index++) {
      final artifact = artifacts[index];
      if (artifact is Map<Object?, Object?>) {
        lines.add(
          '[$index] ${_compactInlineMap(artifact, preferredKeys: const <String>['role', 'relativePath', 'sourcePath', 'byteLength'])}',
        );
      }
    }
  }
  final downloads = _readList(value, 'artifactDownloads');
  if (downloads != null && downloads.isNotEmpty) {
    for (var index = 0; index < downloads.length; index++) {
      final download = downloads[index];
      if (download is Map<Object?, Object?>) {
        final artifact = _readMap(download, 'artifact');
        final role = artifact == null ? null : _readString(artifact, 'role');
        final relativePath = artifact == null
            ? null
            : _readString(artifact, 'relativePath');
        final downloadPath = _readString(download, 'downloadPath');
        lines.add(
          'download[$index] role=${role ?? '?'} path=${relativePath ?? '?'} downloadPath=${downloadPath ?? '?'} deferred=true',
        );
      }
    }
  }
  final artifact = _readMap(value, 'artifact');
  if (artifact != null) {
    lines.add(
      _compactInlineMap(
        artifact,
        preferredKeys: const <String>[
          'role',
          'relativePath',
          'sourcePath',
          'byteLength',
        ],
      ),
    );
  }
  return lines;
}

List<String> _aiBundleLines(Object? value) {
  if (value is! Map<Object?, Object?>) {
    return const <String>[];
  }
  final bundleSummary = _bundleSummaryMapForAi(value);
  if (bundleSummary == null) {
    return const <String>[];
  }
  final lines = <String>[];
  final manifest = _readMap(bundleSummary, 'manifest');
  final evidenceSummary = _readMap(bundleSummary, 'evidenceSummary');
  final artifactPaths = _readMap(bundleSummary, 'artifactPaths');
  final evidence = _readMap(bundleSummary, 'evidence');
  final gateSummary = _readMap(bundleSummary, 'gateSummary');

  final summaryParts = <String>[];
  _addInlinePart(summaryParts, 'dir', _readString(bundleSummary, 'bundleDir'));
  _addInlinePart(summaryParts, 'sessionId', _readString(manifest, 'sessionId'));
  _addInlinePart(summaryParts, 'taskId', _readString(manifest, 'taskId'));
  _addInlinePart(summaryParts, 'platform', _readString(manifest, 'platform'));
  _addInlinePart(summaryParts, 'status', _readString(manifest, 'status'));
  if (summaryParts.isNotEmpty) {
    lines.add('bundle ${summaryParts.join(' ')}');
  }

  final countParts = <String>[];
  _addInlinePart(
    countParts,
    'commands',
    _readNullableNumber(evidenceSummary, 'commandCount'),
  );
  _addInlinePart(
    countParts,
    'failures',
    _readNullableNumber(evidenceSummary, 'failureCount'),
  );
  _addInlinePart(
    countParts,
    'screenshots',
    _readNullableNumber(evidenceSummary, 'screenshotCount'),
  );
  _addInlinePart(
    countParts,
    'recordings',
    _readNullableNumber(evidenceSummary, 'recordingCount'),
  );
  _addInlinePart(
    countParts,
    'keyframes',
    _readNullableNumber(evidenceSummary, 'keyframeCount'),
  );
  if (countParts.isNotEmpty) {
    lines.add('counts ${countParts.join(' ')}');
  }

  final pathParts = <String>[];
  _addInlinePart(
    pathParts,
    'primaryScreenshot',
    _readString(artifactPaths, 'primaryScreenshotPath') ??
        _readString(evidence, 'primaryScreenshotPath'),
  );
  _addInlinePart(
    pathParts,
    'primaryRecording',
    _readString(artifactPaths, 'primaryRecordingPath') ??
        _readString(evidence, 'primaryRecordingPath'),
  );
  if (pathParts.isNotEmpty) {
    lines.add('paths ${pathParts.join(' ')}');
  }

  final gates = _readMap(gateSummary, 'gates');
  if (gates != null) {
    final failedGateNames = gates.entries
        .where((entry) => entry.value == false)
        .map((entry) => entry.key)
        .whereType<String>()
        .take(6)
        .toList(growable: false);
    if (failedGateNames.isNotEmpty) {
      lines.add('failedGates=${failedGateNames.join('|')}');
    }
  }

  return lines;
}

Map<Object?, Object?>? _bundleSummaryMapForAi(Map<Object?, Object?> value) {
  final nested = _readMap(value, 'bundleSummary');
  if (nested != null) {
    return nested;
  }
  if (_readString(value, 'bundleDir') != null &&
      _readMap(value, 'manifest') != null &&
      _readMap(value, 'evidenceSummary') != null) {
    return value;
  }
  return null;
}

List<String> _aiRefLines(Object? value) {
  if (value is! Map<Object?, Object?>) {
    return const <String>[];
  }
  final lines = <String>[];
  _addKeyValue(lines, 'snapshotRef', _readString(value, 'snapshotRef'));
  _addKeyValue(lines, 'appJsonPath', _readString(value, 'appJsonPath'));
  final app = _readMap(value, 'app');
  if (app != null) {
    _addKeyValue(lines, 'appId', _readString(app, 'appId'));
    _addKeyValue(lines, 'baseUrl', _readString(app, 'baseUrl'));
  }
  final sessionHandle = _readMap(value, 'sessionHandle');
  if (sessionHandle != null) {
    _addKeyValue(
      lines,
      'sessionBaseUrl',
      _readString(sessionHandle, 'baseUrl'),
    );
    _addKeyValue(lines, 'deviceId', _readString(sessionHandle, 'deviceId'));
  }
  return lines;
}

List<String> _aiRemainingLines(Object? value) {
  if (value is! Map<Object?, Object?>) {
    return <String>['value=${_formatAiScalar(value)}'];
  }
  final handled = <String>{
    'recommendedNextStep',
    'nextStep',
    'status',
    'classification',
    'state',
    'currentRouteName',
    'routeName',
    'route',
    'appId',
    'sessionId',
    'platform',
    'transportType',
    'selectedPlane',
    'diagnosticLevel',
    'truncated',
    'uiSummary',
    'summary',
    'available',
    'command',
    'results',
    'error',
    'validationFailures',
    'failures',
    'errors',
    'lastError',
    'issueEvidence',
    'artifacts',
    'artifactDownloads',
    'artifact',
    'snapshotRef',
    'appJsonPath',
    'app',
    'sessionHandle',
    'snapshot',
    'bundleSummary',
  };
  if (_bundleSummaryMapForAi(value) == value) {
    handled.addAll(const <String>[
      'bundleDir',
      'manifest',
      'handoff',
      'delivery',
      'acceptanceMarkdown',
      'artifactPaths',
      'evidence',
      'evidenceSummary',
      'gateSummary',
      'baselineEvidence',
      'acceptanceEvidence',
      'acceptanceDelta',
      'diagnosticsArtifactPaths',
      'networkSummary',
      'runtimeSummary',
      'rebuildSummary',
    ]);
  }
  final lines = <String>[];
  for (final entry in value.entries) {
    final key = entry.key;
    if (key is! String || handled.contains(key)) {
      continue;
    }
    final rendered = _renderAiDataLine(key, entry.value);
    if (rendered != null) {
      lines.add(rendered);
    }
  }
  return lines;
}

String? _renderAiDataLine(String key, Object? value) {
  if (_isEmptyAiValue(value)) {
    return null;
  }
  if (value is Map<Object?, Object?>) {
    return '$key=${_compactInlineMap(value)}';
  }
  if (value is List<Object?>) {
    return '$key=[${value.map(_formatAiScalar).join(' | ')}]';
  }
  return '$key=${_formatAiScalar(value)}';
}

void _addKeyValue(List<String> lines, String key, Object? value) {
  if (_isEmptyAiValue(value)) {
    return;
  }
  lines.add('$key=${_formatAiScalar(value)}');
}

void _addInlinePart(List<String> parts, String key, Object? value) {
  if (_isEmptyAiValue(value)) {
    return;
  }
  parts.add('$key=${_formatAiScalar(value)}');
}

bool _isEmptyAiValue(Object? value) {
  if (value == null) {
    return true;
  }
  if (value is String && value.isEmpty) {
    return true;
  }
  if (value is List && value.isEmpty) {
    return true;
  }
  if (value is Map && value.isEmpty) {
    return true;
  }
  return false;
}

String? _firstString(Map<Object?, Object?> map, List<String> keys) {
  for (final key in keys) {
    final value = _readString(map, key);
    if (value != null) {
      return value;
    }
  }
  return null;
}

Map<Object?, Object?>? _readMap(Object? value, String key) {
  if (value is! Map<Object?, Object?>) {
    return null;
  }
  final child = value[key];
  return child is Map<Object?, Object?> ? child : null;
}

List<Object?>? _readList(Map<Object?, Object?> map, String key) {
  final value = map[key];
  return value is List<Object?> ? value : null;
}

Map<Object?, Object?>? _readNestedMap(
  Map<Object?, Object?> map,
  List<String> path,
) {
  Map<Object?, Object?>? cursor = map;
  for (final key in path) {
    if (cursor == null) {
      return null;
    }
    cursor = _readMap(cursor, key);
  }
  return cursor;
}

String? _readNestedString(Map<Object?, Object?>? map, List<String> path) {
  if (map == null || path.isEmpty) {
    return null;
  }
  Map<Object?, Object?>? cursor = map;
  for (var index = 0; index < path.length - 1; index++) {
    if (cursor == null) {
      return null;
    }
    cursor = _readMap(cursor, path[index]);
  }
  return _readString(cursor, path.last);
}

String? _readString(Object? value, String key) {
  if (value is! Map<Object?, Object?>) {
    return null;
  }
  final child = value[key];
  if (child is String && child.isNotEmpty) {
    return child;
  }
  return null;
}

bool? _readBool(Map<Object?, Object?> map, String key) {
  final value = map[key];
  return value is bool ? value : null;
}

num? _readNumber(Map<Object?, Object?> map, String key) {
  final value = map[key];
  return value is num ? value : null;
}

num? _readNullableNumber(Map<Object?, Object?>? map, String key) {
  if (map == null) {
    return null;
  }
  return _readNumber(map, key);
}

String? _joinPreviewList(List<Object?>? values) {
  if (values == null || values.isEmpty) {
    return null;
  }
  return values.map(_formatAiScalar).join(' | ');
}

String _compactInlineMap(
  Map<Object?, Object?> map, {
  List<String>? preferredKeys,
}) {
  final keys = <String>[
    if (preferredKeys != null)
      for (final key in preferredKeys)
        if (map.containsKey(key)) key,
    for (final key in map.keys.whereType<String>())
      if (!(preferredKeys?.contains(key) ?? false)) key,
  ];
  final parts = <String>[];
  for (final key in keys) {
    final value = map[key];
    if (_isEmptyAiValue(value)) {
      continue;
    }
    parts.add('$key=${_formatAiScalar(value)}');
  }
  return parts.join(' ');
}

String _formatAiScalar(Object? value) {
  if (value == null) {
    return 'null';
  }
  if (value is String) {
    return value
        .replaceAll('\r', r'\r')
        .replaceAll('\n', r'\n')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
  if (value is num || value is bool) {
    return '$value';
  }
  if (value is Map<Object?, Object?>) {
    return '{${_compactInlineMap(value)}}';
  }
  if (value is List<Object?>) {
    return '[${value.map(_formatAiScalar).join(' | ')}]';
  }
  return '$value';
}

T cockpitDecodeCliJson<T>({
  required T Function() decode,
  required String label,
  required String usage,
}) {
  try {
    return decode();
  } on FormatException catch (error) {
    throw UsageException('$label is invalid: ${error.message}', usage);
  } on ArgumentError catch (error) {
    throw UsageException('$label is invalid: ${error.message}', usage);
  } on StateError catch (error) {
    throw UsageException('$label is invalid: ${error.message}', usage);
  }
}

Map<String, Object?> cockpitCompactMinimalReadAppPayload(
  Map<String, Object?> payload,
) {
  final compacted = Map<String, Object?>.from(payload)..remove('app');

  final capabilities = payload['capabilities'];
  if (capabilities is Map<Object?, Object?>) {
    final normalizedCapabilities = Map<String, Object?>.from(capabilities);
    normalizedCapabilities.remove('supportedCommands');
    normalizedCapabilities.remove('supportedLocatorStrategies');

    final capabilityProfile = capabilities['capabilityProfile'];
    if (capabilityProfile is Map<Object?, Object?>) {
      final normalizedProfile = Map<String, Object?>.from(capabilityProfile);
      normalizedProfile.remove('actionCapabilities');
      normalizedProfile.remove('evidenceCapabilities');
      normalizedCapabilities['capabilityProfile'] = normalizedProfile;
    }

    compacted['capabilities'] = normalizedCapabilities;
  }

  return compacted;
}
