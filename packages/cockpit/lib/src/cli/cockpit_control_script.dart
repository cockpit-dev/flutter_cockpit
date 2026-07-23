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
      'commands': commands.map((command) => command.toJson()).toList(),
    if (workflowSteps.isNotEmpty)
      'steps': workflowSteps.map((step) => step.toJson()).toList(),
    'failFast': failFast,
  };

  List<CockpitWorkflowStep> get effectiveWorkflowSteps =>
      workflowSteps.isNotEmpty
      ? workflowSteps
      : cockpitWorkflowStepsFromCommands(commands);

  bool get requestsRecording =>
      recording != null || workflowSteps.any(_workflowStepRequestsRecording);

  CockpitControlScript withPlatform(String platform) {
    final normalized = platform.trim();
    if (!cockpitControlScriptSupportedPlatforms.contains(normalized)) {
      throw FormatException(
        'Control script platform must be one of '
        '${cockpitControlScriptSupportedPlatforms.join(', ')}.',
      );
    }
    final current = environment;
    return CockpitControlScript(
      schemaVersion: schemaVersion,
      sessionId: sessionId,
      taskId: taskId,
      platform: normalized,
      environment: current == null
          ? null
          : CockpitEnvironment(
              platform: normalized,
              flutterVersion: current.flutterVersion,
              dartVersion: current.dartVersion,
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
    final commandsJson = json['commands'];
    final stepsJson = json['steps'];
    if (commandsJson != null && commandsJson is! List<Object?> ||
        stepsJson != null && stepsJson is! List<Object?>) {
      throw const FormatException('Control script commands/steps are invalid.');
    }
    final commands = commandsJson as List<Object?>?;
    final steps = stepsJson as List<Object?>?;
    if (commands == null && steps == null ||
        commands != null && commands.isEmpty ||
        steps != null && steps.isEmpty) {
      throw const FormatException(
        'Control script requires non-empty commands or steps.',
      );
    }
    return CockpitControlScript(
      schemaVersion: _readSchemaVersion(json['schemaVersion']),
      sessionId: _requiredString(json, 'sessionId'),
      taskId: _requiredString(json, 'taskId'),
      platform: _requiredString(json, 'platform'),
      environment: environmentJson == null
          ? null
          : CockpitEnvironment.fromJson(
              Map<String, Object?>.from(
                environmentJson as Map<Object?, Object?>,
              ),
            ),
      recording: _recording(json['recording']),
      commands: commands == null
          ? const <CockpitCommand>[]
          : <CockpitCommand>[
              for (var index = 0; index < commands.length; index++)
                CockpitCommand.fromJson(
                  Map<String, Object?>.from(
                    commands[index]! as Map<Object?, Object?>,
                  ),
                ),
            ],
      workflowSteps: steps == null
          ? const <CockpitWorkflowStep>[]
          : cockpitWorkflowStepsFromJson(steps),
      failFast: _optionalBool(json, 'failFast', true),
    );
  }
}

CockpitControlScript cockpitControlScriptFromText(String source) =>
    CockpitControlScript.fromJson(cockpitScriptMapFromText(source));

int _readSchemaVersion(Object? value) {
  if (value == null || value == cockpitControlWorkflowSchemaVersion) {
    return cockpitControlWorkflowSchemaVersion;
  }
  throw const FormatException('Control script schemaVersion is unsupported.');
}

String _requiredString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('Control script $key must be a non-empty string.');
  }
  return value;
}

bool _optionalBool(Map<String, Object?> json, String key, bool fallback) {
  final value = json[key];
  if (value == null) return fallback;
  if (value is bool) return value;
  throw FormatException('Control script $key must be a boolean.');
}

CockpitRecordingRequest? _recording(Object? value) {
  if (value == null) return null;
  if (value is! Map<Object?, Object?>) {
    throw const FormatException('Control script recording must be an object.');
  }
  return CockpitRecordingRequest.fromJson(Map<String, Object?>.from(value));
}

bool _workflowStepRequestsRecording(CockpitWorkflowStep step) => switch (step) {
  CockpitStartRecordingWorkflowStep() => true,
  CockpitStopRecordingWorkflowStep() || CockpitCommandWorkflowStep() => false,
  CockpitIfWorkflowStep() =>
    step.thenSteps.any(_workflowStepRequestsRecording) ||
        step.elseSteps.any(_workflowStepRequestsRecording),
  CockpitLoopWorkflowStep() => step.steps.any(_workflowStepRequestsRecording),
  CockpitRetryWorkflowStep() => _workflowStepRequestsRecording(step.step),
};
