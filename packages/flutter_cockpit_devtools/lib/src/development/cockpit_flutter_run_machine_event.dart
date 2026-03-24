enum CockpitFlutterRunMachineEventKind {
  daemonConnected('daemon.connected'),
  appStart('app.start'),
  appStarted('app.started'),
  appStop('app.stop'),
  appDebugPort('app.debugPort'),
  appProgress('app.progress'),
  daemonLogMessage('daemon.logMessage'),
  request('request'),
  response('response'),
  stdout('stdout'),
  stderr('stderr'),
  processExit('process_exit'),
  unknown('unknown');

  const CockpitFlutterRunMachineEventKind(this.jsonValue);

  final String jsonValue;
}

final class CockpitFlutterRunMachineEvent {
  const CockpitFlutterRunMachineEvent({
    required this.kind,
    this.eventName,
    this.method,
    this.id,
    this.params,
    this.result,
    this.error,
    this.message,
    this.exitCode,
  });

  final CockpitFlutterRunMachineEventKind kind;
  final String? eventName;
  final String? method;
  final int? id;
  final Map<String, Object?>? params;
  final Object? result;
  final Object? error;
  final String? message;
  final int? exitCode;
}
