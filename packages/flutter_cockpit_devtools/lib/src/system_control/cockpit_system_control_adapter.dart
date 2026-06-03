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

int? cockpitReadSystemControlInt(Map<String, Object?> parameters, String key) {
  final value = parameters[key];
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value);
  }
  return null;
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
  final x = cockpitReadSystemControlInt(request.parameters, 'x');
  final y = cockpitReadSystemControlInt(request.parameters, 'y');
  if (x == null || y == null) {
    return CockpitResolvedSystemControlCommand.error(
      code: 'missingSystemActionParameter',
      message: '${request.action.name} requires integer x and y parameters.',
    );
  }
  return factory(x, y);
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
  final startX = cockpitReadSystemControlInt(request.parameters, 'startX');
  final startY = cockpitReadSystemControlInt(request.parameters, 'startY');
  final endX = cockpitReadSystemControlInt(request.parameters, 'endX');
  final endY = cockpitReadSystemControlInt(request.parameters, 'endY');
  final durationMs =
      cockpitReadSystemControlInt(request.parameters, 'durationMs') ?? 300;
  if (startX == null || startY == null || endX == null || endY == null) {
    return const CockpitResolvedSystemControlCommand.error(
      code: 'missingSystemActionParameter',
      message:
          'drag requires integer startX, startY, endX, and endY parameters.',
    );
  }
  return factory(startX, startY, endX, endY, durationMs);
}

CockpitResolvedSystemControlCommand cockpitTextCommand(
  CockpitSystemControlActionRequest request,
  String parameterName,
  CockpitResolvedSystemControlCommand Function(String value) factory,
) {
  final value = request.parameters[parameterName] as String?;
  if (value == null || value.isEmpty) {
    return CockpitResolvedSystemControlCommand.error(
      code: 'missingSystemActionParameter',
      message: '${request.action.name} requires a $parameterName parameter.',
    );
  }
  return factory(value);
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
