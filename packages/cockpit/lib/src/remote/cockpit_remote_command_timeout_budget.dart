import 'package:flutter_cockpit/flutter_cockpit.dart';

const Duration cockpitRemoteCommandDefaultExecutionTimeout = Duration(
  seconds: 4,
);
const Duration cockpitRemoteCommandMinimumTransportTimeout = Duration(
  seconds: 15,
);
const Duration cockpitRemoteCommandPlainTransportHeadroom = Duration(
  seconds: 6,
);
const Duration cockpitRemoteCommandEvidenceTransportHeadroom = Duration(
  seconds: 15,
);

Duration cockpitRemoteCommandTransportTimeoutForCommand(
  CockpitCommand command, {
  Duration minimumTimeout = cockpitRemoteCommandMinimumTransportTimeout,
}) {
  return cockpitRemoteCommandTransportTimeout(
    commandTimeout: _commandTimeoutFromMillis(command.timeoutMs),
    carriesEvidence: cockpitRemoteCommandCarriesEvidence(command),
    minimumTimeout: minimumTimeout,
  );
}

Duration cockpitRemoteCommandTransportTimeoutForJson(
  Map<String, Object?>? commandJson, {
  Duration minimumTimeout = cockpitRemoteCommandMinimumTransportTimeout,
}) {
  return cockpitRemoteCommandTransportTimeout(
    commandTimeout: _commandTimeoutFromMillis(commandJson?['timeoutMs']),
    carriesEvidence: _jsonCommandCarriesEvidence(commandJson),
    minimumTimeout: minimumTimeout,
  );
}

Duration cockpitRemoteCommandTransportTimeout({
  required Duration commandTimeout,
  required bool carriesEvidence,
  Duration minimumTimeout = cockpitRemoteCommandMinimumTransportTimeout,
}) {
  final headroom = carriesEvidence
      ? cockpitRemoteCommandEvidenceTransportHeadroom
      : cockpitRemoteCommandPlainTransportHeadroom;
  final timeout = commandTimeout + headroom;
  return timeout >= minimumTimeout ? timeout : minimumTimeout;
}

bool cockpitRemoteCommandCarriesEvidence(CockpitCommand command) {
  if (command.commandType == CockpitCommandType.captureScreenshot) {
    return true;
  }
  if (command.screenshotRequest != null) {
    return true;
  }
  return switch (command.capturePolicy) {
    CockpitCapturePolicy.afterAction ||
    CockpitCapturePolicy.afterActionAndFailure ||
    CockpitCapturePolicy.onFailure => true,
    CockpitCapturePolicy.none => false,
  };
}

Duration _commandTimeoutFromMillis(Object? value) {
  final timeoutMs = switch (value) {
    int() when value > 0 => value,
    num() when value > 0 => value.toInt(),
    _ => cockpitRemoteCommandDefaultExecutionTimeout.inMilliseconds,
  };
  return Duration(milliseconds: timeoutMs);
}

bool _jsonCommandCarriesEvidence(Map<String, Object?>? commandJson) {
  if (commandJson == null) {
    return false;
  }
  if (commandJson['screenshotRequest'] != null) {
    return true;
  }
  if (commandJson['commandType'] == CockpitCommandType.captureScreenshot.name) {
    return true;
  }
  return switch (commandJson['capturePolicy']) {
    'afterAction' || 'afterActionAndFailure' || 'onFailure' => true,
    _ => false,
  };
}
