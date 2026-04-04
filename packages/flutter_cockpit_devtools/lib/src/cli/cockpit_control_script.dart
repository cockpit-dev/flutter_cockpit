import 'package:flutter_cockpit/flutter_cockpit.dart';

final class CockpitControlScript {
  const CockpitControlScript({
    required this.sessionId,
    required this.taskId,
    required this.platform,
    this.environment,
    this.recording,
    required this.commands,
    required this.failFast,
  });

  final String sessionId;
  final String taskId;
  final String platform;
  final CockpitEnvironment? environment;
  final CockpitRecordingRequest? recording;
  final List<CockpitCommand> commands;
  final bool failFast;

  Map<String, Object?> toJson() => <String, Object?>{
        'sessionId': sessionId,
        'taskId': taskId,
        'platform': platform,
        if (environment != null) 'environment': environment!.toJson(),
        if (recording != null) 'recording': recording!.toJson(),
        'commands':
            commands.map((command) => command.toJson()).toList(growable: false),
        'failFast': failFast,
      };

  factory CockpitControlScript.fromJson(Map<String, Object?> json) {
    final environmentJson = json['environment'];
    if (environmentJson != null && environmentJson is! Map<Object?, Object?>) {
      throw const FormatException(
        'Control script environment must be an object.',
      );
    }

    final commandsJson = json['commands'];
    if (commandsJson is! List<Object?>) {
      throw const FormatException('Control script commands must be a list.');
    }

    return CockpitControlScript(
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
      commands: commandsJson
          .cast<Map<Object?, Object?>>()
          .map(
            (item) => CockpitCommand.fromJson(Map<String, Object?>.from(item)),
          )
          .toList(growable: false),
      failFast: json['failFast'] as bool? ?? true,
    );
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
    return CockpitRecordingRequest.fromJson(
      Map<String, Object?>.from(json),
    );
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
