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
    this.metadata = const <String, Object?>{},
  });

  final String? deviceId;
  final String? appId;
  final int? processId;
  final Map<String, Object?> metadata;

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

CockpitSystemControlStringListParameter
cockpitReadSystemControlStringListParameter(
  Map<String, Object?> parameters,
  String key,
) {
  if (!parameters.containsKey(key)) {
    return const CockpitSystemControlStringListParameter.absent();
  }
  final value = parameters[key];
  if (value is! List) {
    return const CockpitSystemControlStringListParameter.invalid();
  }
  if (value.isEmpty) {
    return const CockpitSystemControlStringListParameter.absent();
  }
  final strings = <String>[];
  for (final item in value) {
    if (item is! String) {
      return const CockpitSystemControlStringListParameter.invalid();
    }
    strings.add(item);
  }
  return CockpitSystemControlStringListParameter.valid(
    List<String>.unmodifiable(strings),
  );
}

final class CockpitSystemControlStringListParameter {
  const CockpitSystemControlStringListParameter._(this.value, this.isPresent);

  const CockpitSystemControlStringListParameter.absent() : this._(null, false);

  const CockpitSystemControlStringListParameter.invalid() : this._(null, true);

  const CockpitSystemControlStringListParameter.valid(List<String> value)
    : this._(value, true);

  final List<String>? value;
  final bool isPresent;

  bool get isValid => value != null;
  bool get isInvalid => isPresent && value == null;
}

CockpitSystemControlBoolParameter cockpitReadSystemControlBoolParameter(
  Map<String, Object?> parameters,
  String key,
) {
  if (!parameters.containsKey(key)) {
    return const CockpitSystemControlBoolParameter.absent();
  }
  final value = parameters[key];
  if (value is bool) {
    return CockpitSystemControlBoolParameter.valid(value);
  }
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    if (normalized.isEmpty) {
      return const CockpitSystemControlBoolParameter.absent();
    }
    if (normalized == 'true' || normalized == 'yes' || normalized == '1') {
      return const CockpitSystemControlBoolParameter.valid(true);
    }
    if (normalized == 'false' || normalized == 'no' || normalized == '0') {
      return const CockpitSystemControlBoolParameter.valid(false);
    }
  }
  return const CockpitSystemControlBoolParameter.invalid();
}

final class CockpitSystemControlBoolParameter {
  const CockpitSystemControlBoolParameter._(this.value, this.isPresent);

  const CockpitSystemControlBoolParameter.absent() : this._(null, false);

  const CockpitSystemControlBoolParameter.invalid() : this._(null, true);

  const CockpitSystemControlBoolParameter.valid(bool value)
    : this._(value, true);

  final bool? value;
  final bool isPresent;

  bool get isValid => value != null;
  bool get isInvalid => isPresent && value == null;
}

CockpitSystemControlDoubleParameter cockpitReadSystemControlDoubleParameter(
  Map<String, Object?> parameters,
  String key, {
  double? minimum,
  double? maximum,
}) {
  if (!parameters.containsKey(key)) {
    return const CockpitSystemControlDoubleParameter.absent();
  }
  final value = parameters[key];
  if (value is num) {
    return _validatedSystemControlDouble(value.toDouble(), minimum, maximum);
  }
  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return const CockpitSystemControlDoubleParameter.absent();
    }
    final parsed = double.tryParse(trimmed);
    if (parsed != null) {
      return _validatedSystemControlDouble(parsed, minimum, maximum);
    }
    return const CockpitSystemControlDoubleParameter.invalid();
  }
  return const CockpitSystemControlDoubleParameter.invalid();
}

CockpitSystemControlDoubleParameter _validatedSystemControlDouble(
  double value,
  double? minimum,
  double? maximum,
) {
  if (!value.isFinite) {
    return const CockpitSystemControlDoubleParameter.invalid();
  }
  if (minimum != null && value < minimum) {
    return const CockpitSystemControlDoubleParameter.invalid();
  }
  if (maximum != null && value > maximum) {
    return const CockpitSystemControlDoubleParameter.invalid();
  }
  return CockpitSystemControlDoubleParameter.valid(value);
}

final class CockpitSystemControlDoubleParameter {
  const CockpitSystemControlDoubleParameter._(this.value, this.isPresent);

  const CockpitSystemControlDoubleParameter.absent() : this._(null, false);

  const CockpitSystemControlDoubleParameter.invalid() : this._(null, true);

  const CockpitSystemControlDoubleParameter.valid(double value)
    : this._(value, true);

  final double? value;
  final bool isPresent;

  bool get isValid => value != null;
  bool get isInvalid => isPresent && value == null;
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
  final command = cockpitReadSystemControlStringListParameter(
    request.parameters,
    'command',
  );
  if (command.isInvalid) {
    return const CockpitResolvedSystemControlCommand.error(
      code: 'invalidSystemActionParameter',
      message: 'runShell requires command to be an array of strings.',
    );
  }
  if (!command.isValid || command.value!.first.trim().isEmpty) {
    return const CockpitResolvedSystemControlCommand.error(
      code: 'missingSystemActionParameter',
      message: 'runShell requires a command array parameter.',
    );
  }
  return factory(command.value!);
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
  final latitude = cockpitReadSystemControlDoubleParameter(
    request.parameters,
    'latitude',
    minimum: -90,
    maximum: 90,
  );
  final longitude = cockpitReadSystemControlDoubleParameter(
    request.parameters,
    'longitude',
    minimum: -180,
    maximum: 180,
  );
  final altitude = cockpitReadSystemControlDoubleParameter(
    request.parameters,
    'altitude',
  );
  if (latitude.isInvalid || longitude.isInvalid || altitude.isInvalid) {
    return const CockpitResolvedSystemControlCommand.error(
      code: 'invalidSystemActionParameter',
      message:
          'setLocation latitude must be between -90 and 90 and longitude between -180 and 180.',
    );
  }
  if (!latitude.isValid || !longitude.isValid) {
    return const CockpitResolvedSystemControlCommand.error(
      code: 'missingSystemActionParameter',
      message: 'setLocation requires latitude and longitude parameters.',
    );
  }
  return factory(latitude.value!, longitude.value!, altitude.value);
}

bool cockpitHasSystemControlWindowTarget({
  required String? appId,
  required int? processId,
}) {
  return (appId != null && appId.trim().isNotEmpty) || processId != null;
}
