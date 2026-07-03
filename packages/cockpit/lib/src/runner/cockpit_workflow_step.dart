import 'dart:convert';

import 'package:flutter_cockpit_protocol/flutter_cockpit_protocol.dart';
import 'package:yaml/yaml.dart';

sealed class CockpitWorkflowStep {
  const CockpitWorkflowStep({required this.stepId, this.description});

  final String stepId;
  final String? description;

  String get stepType;

  Map<String, Object?> toJson();

  factory CockpitWorkflowStep.fromJson(
    Map<String, Object?> json, {
    required String path,
  }) {
    final rawType = json['stepType'] ?? json['type'];
    final stepType = _readStringValue(rawType, '$path.stepType');
    final stepId = _readOptionalString(json['stepId']) ?? path;
    final description = _readOptionalDescription(
      json['description'],
      '$path.description',
    );
    return switch (stepType) {
      'command' => CockpitCommandWorkflowStep(
        stepId: stepId,
        description: description,
        command: _readCommand(json['command'], '$path.command'),
      ),
      'startRecording' => CockpitStartRecordingWorkflowStep(
        stepId: stepId,
        description: description,
        recording: _readRecordingRequest(json['recording'], '$path.recording'),
      ),
      'stopRecording' => CockpitStopRecordingWorkflowStep(
        stepId: stepId,
        description: description,
        settleDelay: Duration(
          milliseconds: _readNonNegativeInt(
            json['settleMs'],
            '$path.settleMs',
            defaultValue: 1400,
          ),
        ),
      ),
      'if' => CockpitIfWorkflowStep(
        stepId: stepId,
        description: description,
        condition: _readCommand(json['condition'], '$path.condition'),
        thenSteps: _readWorkflowSteps(
          json['thenSteps'],
          '$path.thenSteps',
          defaultValue: const <CockpitWorkflowStep>[],
        ),
        elseSteps: _readWorkflowSteps(
          json['elseSteps'],
          '$path.elseSteps',
          defaultValue: const <CockpitWorkflowStep>[],
        ),
      ),
      'loop' => CockpitLoopWorkflowStep(
        stepId: stepId,
        description: description,
        maxIterations: _readPositiveInt(
          json['maxIterations'],
          '$path.maxIterations',
        ),
        condition: _readCommand(json['condition'], '$path.condition'),
        steps: _readWorkflowSteps(json['steps'], '$path.steps'),
      ),
      'retry' => CockpitRetryWorkflowStep(
        stepId: stepId,
        description: description,
        maxAttempts: _readPositiveInt(
          json['maxAttempts'],
          '$path.maxAttempts',
          defaultValue: 3,
        ),
        delayMs: _readNonNegativeInt(
          json['delayMs'],
          '$path.delayMs',
          defaultValue: 0,
        ),
        step: _readRetryCommandStep(json['step'], '$path.step'),
      ),
      _ => throw FormatException(
        'Unsupported workflow stepType "$stepType" at $path.',
      ),
    };
  }
}

final class CockpitStartRecordingWorkflowStep extends CockpitWorkflowStep {
  const CockpitStartRecordingWorkflowStep({
    required super.stepId,
    super.description,
    required this.recording,
  });

  final CockpitRecordingRequest recording;

  @override
  String get stepType => 'startRecording';

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'stepId': stepId,
    'stepType': stepType,
    if (description != null) 'description': description,
    'recording': recording.toJson(),
  };
}

final class CockpitStopRecordingWorkflowStep extends CockpitWorkflowStep {
  const CockpitStopRecordingWorkflowStep({
    required super.stepId,
    super.description,
    this.settleDelay = const Duration(milliseconds: 1400),
  });

  final Duration settleDelay;

  @override
  String get stepType => 'stopRecording';

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'stepId': stepId,
    'stepType': stepType,
    if (description != null) 'description': description,
    'settleMs': settleDelay.inMilliseconds,
  };
}

final class CockpitCommandWorkflowStep extends CockpitWorkflowStep {
  const CockpitCommandWorkflowStep({
    required super.stepId,
    super.description,
    required this.command,
  });

  final CockpitCommand command;

  @override
  String get stepType => 'command';

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'stepId': stepId,
    'stepType': stepType,
    if (description != null) 'description': description,
    'command': command.toJson(),
  };
}

final class CockpitIfWorkflowStep extends CockpitWorkflowStep {
  const CockpitIfWorkflowStep({
    required super.stepId,
    super.description,
    required this.condition,
    required this.thenSteps,
    this.elseSteps = const <CockpitWorkflowStep>[],
  });

  final CockpitCommand condition;
  final List<CockpitWorkflowStep> thenSteps;
  final List<CockpitWorkflowStep> elseSteps;

  @override
  String get stepType => 'if';

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'stepId': stepId,
    'stepType': stepType,
    if (description != null) 'description': description,
    'condition': condition.toJson(),
    'thenSteps': thenSteps.map((step) => step.toJson()).toList(growable: false),
    if (elseSteps.isNotEmpty)
      'elseSteps': elseSteps
          .map((step) => step.toJson())
          .toList(growable: false),
  };
}

final class CockpitLoopWorkflowStep extends CockpitWorkflowStep {
  const CockpitLoopWorkflowStep({
    required super.stepId,
    super.description,
    required this.maxIterations,
    required this.condition,
    required this.steps,
  });

  final int maxIterations;
  final CockpitCommand condition;
  final List<CockpitWorkflowStep> steps;

  @override
  String get stepType => 'loop';

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'stepId': stepId,
    'stepType': stepType,
    if (description != null) 'description': description,
    'maxIterations': maxIterations,
    'condition': condition.toJson(),
    'steps': steps.map((step) => step.toJson()).toList(growable: false),
  };
}

final class CockpitRetryWorkflowStep extends CockpitWorkflowStep {
  const CockpitRetryWorkflowStep({
    required super.stepId,
    super.description,
    required this.maxAttempts,
    required this.delayMs,
    required this.step,
  });

  final int maxAttempts;
  final int delayMs;
  final CockpitWorkflowStep step;

  @override
  String get stepType => 'retry';

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'stepId': stepId,
    'stepType': stepType,
    if (description != null) 'description': description,
    'maxAttempts': maxAttempts,
    'delayMs': delayMs,
    'step': step.toJson(),
  };
}

List<CockpitWorkflowStep> cockpitWorkflowStepsFromCommands(
  List<CockpitCommand> commands,
) => commands
    .map(
      (command) => CockpitCommandWorkflowStep(
        stepId: command.commandId,
        command: command,
      ),
    )
    .toList(growable: false);

List<CockpitWorkflowStep> cockpitWorkflowStepsFromJson(Object? value) =>
    _readWorkflowSteps(value, 'steps');

Map<String, Object?> cockpitScriptMapFromText(String source) {
  final text = source.trimLeft();
  if (text.startsWith('{')) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<Object?, Object?>) {
      throw const FormatException(
        'Control script JSON must decode to an object.',
      );
    }
    return _stringKeyedMap(decoded, 'script');
  }

  final decoded = loadYaml(source);
  if (decoded is! YamlMap && decoded is! Map<Object?, Object?>) {
    throw const FormatException(
      'Control script YAML must decode to an object.',
    );
  }
  return _stringKeyedMap(decoded as Map<Object?, Object?>, 'script');
}

List<CockpitWorkflowStep> _readWorkflowSteps(
  Object? value,
  String path, {
  List<CockpitWorkflowStep>? defaultValue,
}) {
  if (value == null) {
    if (defaultValue != null) {
      return defaultValue;
    }
    throw FormatException('Workflow $path must be a non-empty list.');
  }
  final List<Object?> list;
  if (value is YamlList) {
    list = value.toList(growable: false);
  } else if (value is List<Object?>) {
    list = value;
  } else {
    throw FormatException('Workflow $path must be a list.');
  }
  if (list.isEmpty) {
    if (defaultValue != null) {
      return defaultValue;
    }
    throw FormatException('Workflow $path must not be empty.');
  }
  return <CockpitWorkflowStep>[
    for (var index = 0; index < list.length; index += 1)
      _readWorkflowStep(list[index], '$path[$index]'),
  ];
}

CockpitWorkflowStep _readWorkflowStep(Object? value, String path) {
  if (value is! Map<Object?, Object?>) {
    throw FormatException('Workflow step at $path must be an object.');
  }
  return CockpitWorkflowStep.fromJson(_stringKeyedMap(value, path), path: path);
}

CockpitCommandWorkflowStep _readRetryCommandStep(Object? value, String path) {
  final step = _readWorkflowStep(value, path);
  if (step is CockpitCommandWorkflowStep) {
    return step;
  }
  throw FormatException(
    'Workflow retry step must wrap a command step at $path.',
  );
}

CockpitCommand _readCommand(Object? value, String path) {
  if (value is! Map<Object?, Object?>) {
    throw FormatException('Workflow command at $path must be an object.');
  }
  return CockpitCommand.fromJson(_stringKeyedMap(value, path));
}

CockpitRecordingRequest _readRecordingRequest(Object? value, String path) {
  if (value is! Map<Object?, Object?>) {
    throw FormatException('Workflow recording at $path must be an object.');
  }
  return CockpitRecordingRequest.fromJson(_stringKeyedMap(value, path));
}

Map<String, Object?> _stringKeyedMap(Map<Object?, Object?> value, String path) {
  final result = <String, Object?>{};
  for (final entry in value.entries) {
    final key = entry.key;
    if (key is! String || key.isEmpty) {
      throw FormatException('Object keys at $path must be non-empty strings.');
    }
    result[key] = _normalizeYamlValue(entry.value, '$path.$key');
  }
  return result;
}

Object? _normalizeYamlValue(Object? value, String path) {
  if (value is YamlMap || value is Map<Object?, Object?>) {
    return _stringKeyedMap(value as Map<Object?, Object?>, path);
  }
  if (value is YamlList || value is List<Object?>) {
    return (value as List<Object?>)
        .map((item) => _normalizeYamlValue(item, path))
        .toList(growable: false);
  }
  return value;
}

String _readStringValue(Object? value, String path) {
  if (value is String && value.isNotEmpty) {
    return value;
  }
  throw FormatException('$path must be a non-empty string.');
}

String? _readOptionalString(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is String && value.isNotEmpty) {
    return value;
  }
  throw const FormatException('Workflow stepId must be a non-empty string.');
}

String? _readOptionalDescription(Object? value, String path) {
  if (value == null) {
    return null;
  }
  if (value is String && value.trim().isNotEmpty) {
    return value;
  }
  throw FormatException('$path must be a non-empty string.');
}

int _readPositiveInt(Object? value, String path, {int? defaultValue}) {
  if (value == null && defaultValue != null) {
    return defaultValue;
  }
  if (value is int && value > 0) {
    return value;
  }
  throw FormatException('$path must be a positive integer.');
}

int _readNonNegativeInt(Object? value, String path, {int? defaultValue}) {
  if (value == null && defaultValue != null) {
    return defaultValue;
  }
  if (value is int && value >= 0) {
    return value;
  }
  throw FormatException('$path must be a non-negative integer.');
}
