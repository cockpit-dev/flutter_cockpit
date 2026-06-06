import 'cockpit_system_control_action.dart';
import 'cockpit_system_control_profile.dart';

abstract interface class CockpitSystemControlAdapter {
  String get platform;

  CockpitSystemControlProfile describe(
    CockpitSystemControlTargetContext target,
  );

  CockpitResolvedSystemControlCommand resolveCommand(
    CockpitSystemControlActionRequest request,
  );
}

final class CockpitSystemControlTargetContext {
  const CockpitSystemControlTargetContext({
    this.deviceId,
    this.appId,
    this.processId,
  });

  final String? deviceId;
  final String? appId;
  final int? processId;

  bool get hasWindowTarget =>
      cockpitHasSystemControlWindowTarget(appId: appId, processId: processId);
}

CockpitSystemControlIntParameter cockpitReadSystemControlIntParameter(
  Map<String, Object?> parameters,
  String key, {
  int? minimum,
  int? maximum,
}) {
  if (!parameters.containsKey(key)) {
    return const CockpitSystemControlIntParameter.absent();
  }
  final value = parameters[key];
  if (value is int) {
    return _validatedSystemControlInt(value, minimum, maximum);
  }
  if (value is num) {
    if (value.isFinite && value == value.truncateToDouble()) {
      return _validatedSystemControlInt(value.toInt(), minimum, maximum);
    }
    return CockpitSystemControlIntParameter.invalid();
  }
  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return const CockpitSystemControlIntParameter.absent();
    }
    final parsed = int.tryParse(trimmed);
    if (parsed != null) {
      return _validatedSystemControlInt(parsed, minimum, maximum);
    }
    return CockpitSystemControlIntParameter.invalid();
  }
  return CockpitSystemControlIntParameter.invalid();
}

CockpitSystemControlIntParameter _validatedSystemControlInt(
  int value,
  int? minimum,
  int? maximum,
) {
  if (minimum != null && value < minimum) {
    return CockpitSystemControlIntParameter.invalid();
  }
  if (maximum != null && value > maximum) {
    return CockpitSystemControlIntParameter.invalid();
  }
  return CockpitSystemControlIntParameter.valid(value);
}

final class CockpitSystemControlIntParameter {
  const CockpitSystemControlIntParameter._(this.value, this.isPresent);

  const CockpitSystemControlIntParameter.absent() : this._(null, false);

  const CockpitSystemControlIntParameter.invalid() : this._(null, true);

  const CockpitSystemControlIntParameter.valid(int value) : this._(value, true);

  final int? value;
  final bool isPresent;

  bool get isValid => value != null;
  bool get isInvalid => isPresent && value == null;
}

CockpitSystemControlStringParameter cockpitReadSystemControlStringParameter(
  Map<String, Object?> parameters,
  String key, {
  List<String> allowedValues = const <String>[],
  bool trim = true,
}) {
  if (!parameters.containsKey(key)) {
    return const CockpitSystemControlStringParameter.absent();
  }
  final value = parameters[key];
  if (value is! String) {
    return const CockpitSystemControlStringParameter.invalid();
  }
  final normalized = trim ? value.trim() : value;
  if (normalized.isEmpty) {
    return const CockpitSystemControlStringParameter.absent();
  }
  if (allowedValues.isNotEmpty && !allowedValues.contains(normalized)) {
    return const CockpitSystemControlStringParameter.invalid();
  }
  return CockpitSystemControlStringParameter.valid(normalized);
}

CockpitSystemControlStringParameter
cockpitReadFirstSystemControlStringParameter(
  Map<String, Object?> parameters,
  List<String> keys, {
  List<String> allowedValues = const <String>[],
  bool trim = true,
}) {
  for (final key in keys) {
    final value = cockpitReadSystemControlStringParameter(
      parameters,
      key,
      allowedValues: allowedValues,
      trim: trim,
    );
    if (value.isPresent) {
      return value;
    }
  }
  return const CockpitSystemControlStringParameter.absent();
}

final class CockpitSystemControlStringParameter {
  const CockpitSystemControlStringParameter._(this.value, this.isPresent);

  const CockpitSystemControlStringParameter.absent() : this._(null, false);

  const CockpitSystemControlStringParameter.invalid() : this._(null, true);

  const CockpitSystemControlStringParameter.valid(String value)
    : this._(value, true);

  final String? value;
  final bool isPresent;

  bool get isValid => value != null;
  bool get isInvalid => isPresent && value == null;
}

double? cockpitReadSystemControlDouble(
  Map<String, Object?> parameters,
  String key,
) {
  final value = parameters[key];
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value);
  }
  return null;
}

CockpitResolvedSystemControlCommand cockpitCoordinateCommand(
  CockpitSystemControlActionRequest request,
  CockpitResolvedSystemControlCommand Function(int x, int y) factory,
) {
  final x = cockpitReadSystemControlIntParameter(request.parameters, 'x');
  final y = cockpitReadSystemControlIntParameter(request.parameters, 'y');
  if (x.isInvalid || y.isInvalid) {
    return CockpitResolvedSystemControlCommand.error(
      code: 'invalidSystemActionParameter',
      message: '${request.action.name} requires integer x and y parameters.',
    );
  }
  if (!x.isValid || !y.isValid) {
    return CockpitResolvedSystemControlCommand.error(
      code: 'missingSystemActionParameter',
      message: '${request.action.name} requires integer x and y parameters.',
    );
  }
  return factory(x.value!, y.value!);
}

CockpitResolvedSystemControlCommand cockpitLongPressCommand(
  CockpitSystemControlActionRequest request,
  CockpitResolvedSystemControlCommand Function(int x, int y, int durationMs)
  factory,
) {
  final x = cockpitReadSystemControlIntParameter(request.parameters, 'x');
  final y = cockpitReadSystemControlIntParameter(request.parameters, 'y');
  final durationMs = cockpitReadSystemControlIntParameter(
    request.parameters,
    'durationMs',
    minimum: 1,
  );
  if (x.isInvalid || y.isInvalid || durationMs.isInvalid) {
    return CockpitResolvedSystemControlCommand.error(
      code: 'invalidSystemActionParameter',
      message:
          '${request.action.name} requires integer x, y, and positive durationMs parameters.',
    );
  }
  if (!x.isValid || !y.isValid) {
    return CockpitResolvedSystemControlCommand.error(
      code: 'missingSystemActionParameter',
      message: '${request.action.name} requires integer x and y parameters.',
    );
  }
  return factory(x.value!, y.value!, durationMs.value ?? 800);
}

CockpitResolvedSystemControlCommand cockpitDragCommand(
  CockpitSystemControlActionRequest request,
  CockpitResolvedSystemControlCommand Function(
    int startX,
    int startY,
    int endX,
    int endY,
    int durationMs,
  )
  factory,
) {
  final startX = cockpitReadSystemControlIntParameter(
    request.parameters,
    'startX',
  );
  final startY = cockpitReadSystemControlIntParameter(
    request.parameters,
    'startY',
  );
  final endX = cockpitReadSystemControlIntParameter(request.parameters, 'endX');
  final endY = cockpitReadSystemControlIntParameter(request.parameters, 'endY');
  final durationMs = cockpitReadSystemControlIntParameter(
    request.parameters,
    'durationMs',
    minimum: 1,
  );
  if (startX.isInvalid ||
      startY.isInvalid ||
      endX.isInvalid ||
      endY.isInvalid ||
      durationMs.isInvalid) {
    return const CockpitResolvedSystemControlCommand.error(
      code: 'invalidSystemActionParameter',
      message:
          'drag requires integer startX, startY, endX, endY, and positive durationMs parameters.',
    );
  }
  if (!startX.isValid || !startY.isValid || !endX.isValid || !endY.isValid) {
    return const CockpitResolvedSystemControlCommand.error(
      code: 'missingSystemActionParameter',
      message:
          'drag requires integer startX, startY, endX, and endY parameters.',
    );
  }
  return factory(
    startX.value!,
    startY.value!,
    endX.value!,
    endY.value!,
    durationMs.value ?? 300,
  );
}

CockpitResolvedSystemControlCommand cockpitTextCommand(
  CockpitSystemControlActionRequest request,
  String parameterName,
  CockpitResolvedSystemControlCommand Function(String value) factory, {
  bool trim = false,
  List<String> allowedValues = const <String>[],
}) {
  final value = cockpitReadSystemControlStringParameter(
    request.parameters,
    parameterName,
    trim: trim,
    allowedValues: allowedValues,
  );
  if (value.isInvalid) {
    return CockpitResolvedSystemControlCommand.error(
      code: 'invalidSystemActionParameter',
      message:
          '${request.action.name} requires a valid $parameterName parameter.',
    );
  }
  if (!value.isValid) {
    return CockpitResolvedSystemControlCommand.error(
      code: 'missingSystemActionParameter',
      message: '${request.action.name} requires a $parameterName parameter.',
    );
  }
  return factory(value.value!);
}

CockpitResolvedSystemControlCommand cockpitShellCommand(
  CockpitSystemControlActionRequest request,
  CockpitResolvedSystemControlCommand Function(List<String> command) factory,
) {
  final raw = request.parameters['command'];
  final command = raw is List<Object?>
      ? raw.map((value) => '$value').where((value) => value.isNotEmpty).toList()
      : const <String>[];
  if (command.isEmpty) {
    return const CockpitResolvedSystemControlCommand.error(
      code: 'missingSystemActionParameter',
      message: 'runShell requires a command array parameter.',
    );
  }
  return factory(command);
}

CockpitResolvedSystemControlCommand cockpitLocationCommand(
  CockpitSystemControlActionRequest request,
  CockpitResolvedSystemControlCommand Function(
    double latitude,
    double longitude,
    double? altitude,
  )
  factory,
) {
  final latitude =
      cockpitReadSystemControlDouble(request.parameters, 'latitude') ??
      cockpitReadSystemControlDouble(request.parameters, 'lat');
  final longitude =
      cockpitReadSystemControlDouble(request.parameters, 'longitude') ??
      cockpitReadSystemControlDouble(request.parameters, 'lon') ??
      cockpitReadSystemControlDouble(request.parameters, 'lng');
  final altitude = cockpitReadSystemControlDouble(
    request.parameters,
    'altitude',
  );
  if (latitude == null || longitude == null) {
    return const CockpitResolvedSystemControlCommand.error(
      code: 'missingSystemActionParameter',
      message: 'setLocation requires latitude and longitude parameters.',
    );
  }
  if (latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) {
    return const CockpitResolvedSystemControlCommand.error(
      code: 'invalidSystemActionParameter',
      message:
          'setLocation latitude must be between -90 and 90 and longitude between -180 and 180.',
    );
  }
  return factory(latitude, longitude, altitude);
}

bool cockpitHasSystemControlWindowTarget({
  required String? appId,
  required int? processId,
}) {
  return (appId != null && appId.trim().isNotEmpty) || processId != null;
}
