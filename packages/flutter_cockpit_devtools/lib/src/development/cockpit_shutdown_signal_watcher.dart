import 'dart:async';
import 'dart:io';

typedef CockpitShutdownSignalLogger = Future<void> Function(String message);
typedef CockpitShutdownStopper = Future<void> Function();
typedef CockpitProcessSignalWatcher =
    Stream<ProcessSignal> Function(ProcessSignal signal);

Future<StreamSubscription<ProcessSignal>?> cockpitWatchShutdownSignal({
  required ProcessSignal signal,
  required CockpitShutdownSignalLogger writeLog,
  required CockpitShutdownStopper stop,
  bool isWindows = false,
  CockpitProcessSignalWatcher watchSignal = _watchProcessSignal,
}) async {
  if (isWindows) {
    await writeLog('shutdown signal skipped on Windows signal=$signal');
    return null;
  }

  try {
    final subscription = watchSignal(signal).listen(
      (_) {
        unawaited(stop());
      },
      onError: (Object error, StackTrace stackTrace) {
        unawaited(
          writeLog('shutdown signal stream error signal=$signal error=$error'),
        );
      },
    );
    await writeLog('shutdown signal registered signal=$signal');
    return subscription;
  } on Object catch (error) {
    await writeLog('shutdown signal unsupported signal=$signal error=$error');
    return null;
  }
}

Stream<ProcessSignal> _watchProcessSignal(ProcessSignal signal) {
  return signal.watch();
}
