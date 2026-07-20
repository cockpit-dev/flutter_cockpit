import 'package:cockpit_protocol/cockpit_protocol.dart';

import '../runner/cockpit_workflow_step.dart';

const int cockpitControlWorkflowSchemaVersion = 1;
const List<String> cockpitControlScriptSupportedPlatforms = <String>[
  'android',
  'ios',
  'macos',
  'windows',
  'linux',
  'web',
];

final class CockpitControlScript {
  const CockpitControlScript({
    this.schemaVersion = cockpitControlWorkflowSchemaVersion,
    required this.sessionId,
    required this.taskId,
    required this.platform,
    this.environment,
    this.recording,
    this.commands = const <CockpitCommand>[],
    this.workflowSteps = const <CockpitWorkflowStep>[],
    required this.failFast,
  });

  final int schemaVersion;
  final String sessionId;
  final String taskId;
  final String platform;
  final CockpitEnvironment? environment;
  final CockpitRecordingRequest? recording;
  final List<CockpitCommand> commands;
  final List<CockpitWorkflowStep> workflowSteps;
  final bool failFast;

  Map<String, Object?> toJson() => <String, Object?>{
    'schemaVersion': schemaVersion,
    'sessionId': sessionId,
    'taskId': taskId,
    'platform': platform,
    if (environment != null) 'environment': environment!.toJson(),
    if (recording != null) 'recording': recording!.toJson(),
    if (commands.isNotEmpty)
      'commands': commands
          .map((command) => command.toJson())
          .toList(growable: false),
    if (workflowSteps.isNotEmpty)
      'steps': workflowSteps
          .map((step) => step.toJson())
          .toList(growable: false),
    'failFast': failFast,
  };

  List<CockpitWorkflowStep> get effectiveWorkflowSteps =>
      workflowSteps.isNotEmpty
      ? workflowSteps
      : cockpitWorkflowStepsFromCommands(commands);

  bool get requestsRecording =>
      recording != null || workflowSteps.any(_workflowStepRequestsRecording);

  CockpitControlScript withPlatform(String platform) {
    final normalizedPlatform = platform.trim();
    if (normalizedPlatform.isEmpty) {
      throw const FormatException(
        'Control script platform override must be a non-empty string.',
      );
    }
    if (!cockpitControlScriptSupportedPlatforms.contains(normalizedPlatform)) {
      throw FormatException(
        'Control script platform override must be one of '
        '${cockpitControlScriptSupportedPlatforms.join(', ')}.',
      );
    }
    final currentEnvironment = environment;
    return CockpitControlScript(
      schemaVersion: schemaVersion,
      sessionId: sessionId,
      taskId: taskId,
      platform: normalizedPlatform,
      environment: currentEnvironment == null
          ? null
          : CockpitEnvironment(
              platform: normalizedPlatform,
              flutterVersion: currentEnvironment.flutterVersion,
              dartVersion: currentEnvironment.dartVersion,
            ),
      recording: recording,
      commands: commands,
      workflowSteps: workflowSteps,
      failFast: failFast,
    );
  }

  factory CockpitControlScript.fromJson(Map<String, Object?> json) {
    final environmentJson = json['environment'];
    if (environmentJson != null && environmentJson is! Map<Object?, Object?>) {
      throw const FormatException(
        'Control script environment must be an object.',
      );
    }
    final schemaVersion = _readSchemaVersion(json['schemaVersion']);

    final commandsJson = json['commands'];
    if (commandsJson != null && commandsJson is! List<Object?>) {
      throw const FormatException('Control script commands must be a list.');
    }
    final commandListJson = commandsJson as List<Object?>?;
    final stepsJson = json['steps'];
    if (stepsJson != null && stepsJson is! List<Object?>) {
      throw const FormatException('Control script steps must be a list.');
    }
    final stepListJson = stepsJson as List<Object?>?;
    if (commandListJson == null && stepListJson == null) {
      throw const FormatException(
        'Control script must include commands or steps.',
      );
    }
    if (commandListJson != null && commandListJson.isEmpty) {
      throw const FormatException('Control script commands must not be empty.');
    }
    if (stepListJson != null && stepListJson.isEmpty) {
      throw const FormatException('Control script steps must not be empty.');
    }

    return CockpitControlScript(
      schemaVersion: schemaVersion,
      sessionId: _readRequiredString(json, 'sessionId'),
      taskId: _readRequiredString(json, 'taskId'),
      platform: _readRequiredString(json, 'platform'),
      environment: environmentJson == null
          ? null
          : CockpitEnvironment.fromJson(
              Map<String, Object?>.from(
                environmentJson as Map<Object?, Object?>,
              ),
            ),
      recording: _readRecording(json['recording']),
      commands: commandListJson == null
          ? const <CockpitCommand>[]
          : _readCommands(commandListJson),
      workflowSteps: stepListJson == null
          ? const <CockpitWorkflowStep>[]
          : cockpitWorkflowStepsFromJson(stepListJson),
      failFast: _readOptionalBool(json, 'failFast', defaultValue: true),
    );
  }

  static List<CockpitCommand> _readCommands(List<Object?> json) {
    return <CockpitCommand>[
      for (var index = 0; index < json.length; index += 1)
        _readCommand(json[index], 'commands[$index]'),
    ];
  }

  static CockpitCommand _readCommand(Object? value, String path) {
    if (value is! Map<Object?, Object?>) {
      throw FormatException(
        'Control script command at $path must be an object.',
      );
    }
    return CockpitCommand.fromJson(Map<String, Object?>.from(value));
  }

  static CockpitRecordingRequest? _readRecording(Object? json) {
    if (json == null) {
      return null;
    }
    if (json is! Map<Object?, Object?>) {
      throw const FormatException(
        'Control script recording must be an object.',
      );
    }
    return CockpitRecordingRequest.fromJson(Map<String, Object?>.from(json));
  }

  static int _readSchemaVersion(Object? value) {
    if (value == null) {
      return cockpitControlWorkflowSchemaVersion;
    }
    if (value == cockpitControlWorkflowSchemaVersion) {
      return cockpitControlWorkflowSchemaVersion;
    }
    throw FormatException(
      'Control script schemaVersion must be '
      '$cockpitControlWorkflowSchemaVersion.',
    );
  }

  static bool _readOptionalBool(
    Map<String, Object?> json,
    String key, {
    required bool defaultValue,
  }) {
    final value = json[key];
    if (value == null) {
      return defaultValue;
    }
    if (value is bool) {
      return value;
    }
    throw FormatException('Control script $key must be a boolean.');
  }

  static String _readRequiredString(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is! String || value.isEmpty) {
      throw FormatException(
        'Control script "$key" must be a non-empty string.',
      );
    }
    return value;
  }
}

CockpitControlScript cockpitControlScriptFromText(String source) {
  return CockpitControlScript.fromJson(cockpitScriptMapFromText(source));
}

bool _workflowStepRequestsRecording(CockpitWorkflowStep step) {
  return switch (step) {
    CockpitStartRecordingWorkflowStep() => true,
    CockpitStopRecordingWorkflowStep() => false,
    CockpitCommandWorkflowStep() => false,
    CockpitIfWorkflowStep() =>
      step.thenSteps.any(_workflowStepRequestsRecording) ||
          step.elseSteps.any(_workflowStepRequestsRecording),
    CockpitLoopWorkflowStep() => step.steps.any(_workflowStepRequestsRecording),
    CockpitRetryWorkflowStep() => _workflowStepRequestsRecording(step.step),
  };
}
