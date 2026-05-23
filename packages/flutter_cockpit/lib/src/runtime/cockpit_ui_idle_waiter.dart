import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

typedef CockpitUiIdleTickHandler = Future<void> Function(Duration duration);
typedef CockpitUiIdleNetworkWaiter =
    Future<bool> Function({
      required Duration quietWindow,
      required Duration timeout,
    });

Future<bool> waitForCockpitUiIdle({
  required Duration quietWindow,
  required Duration timeout,
  required CockpitUiIdleTickHandler waitTick,
  CockpitUiIdleNetworkWaiter? waitForNetworkIdle,
  bool includeNetworkIdle = true,
}) async {
  final deadline = DateTime.now().add(timeout);

  final schedulerSettled = await _waitForSchedulerQuiet(
    deadline: deadline,
    quietWindow: quietWindow,
    waitTick: waitTick,
  );
  if (!schedulerSettled) {
    return false;
  }

  if (!includeNetworkIdle || waitForNetworkIdle == null) {
    return true;
  }

  final remainingBeforeNetwork = deadline.difference(DateTime.now());
  if (remainingBeforeNetwork <= Duration.zero) {
    return false;
  }

  final networkSettled = await waitForNetworkIdle(
    quietWindow: quietWindow,
    timeout: remainingBeforeNetwork,
  );
  if (!networkSettled) {
    return false;
  }

  return _waitForSchedulerQuiet(
    deadline: deadline,
    quietWindow: quietWindow,
    waitTick: waitTick,
  );
}

Future<bool> _waitForSchedulerQuiet({
  required DateTime deadline,
  required Duration quietWindow,
  required CockpitUiIdleTickHandler waitTick,
}) async {
  SchedulerBinding schedulerBinding;
  WidgetsBinding widgetsBinding;
  try {
    schedulerBinding = SchedulerBinding.instance;
    widgetsBinding = WidgetsBinding.instance;
  } on Object {
    return true;
  }

  if (_isTestBinding(widgetsBinding)) {
    return true;
  }

  DateTime? quietSince;
  while (DateTime.now().isBefore(deadline)) {
    await Future<void>.microtask(() {});
    final isIdle =
        schedulerBinding.schedulerPhase == SchedulerPhase.idle &&
        !schedulerBinding.hasScheduledFrame;
    if (isIdle) {
      quietSince ??= DateTime.now();
      if (DateTime.now().difference(quietSince) >= quietWindow) {
        return true;
      }
    } else {
      quietSince = null;
      await _awaitFrameIfScheduled(schedulerBinding, widgetsBinding);
    }
    await waitTick(const Duration(milliseconds: 16));
  }
  return false;
}

Future<void> _awaitFrameIfScheduled(
  SchedulerBinding schedulerBinding,
  WidgetsBinding widgetsBinding,
) async {
  if (!schedulerBinding.hasScheduledFrame) {
    return;
  }
  try {
    await widgetsBinding.endOfFrame.timeout(const Duration(milliseconds: 50));
  } on TimeoutException {
    return;
  }
}

bool _isTestBinding(WidgetsBinding widgetsBinding) {
  return widgetsBinding.runtimeType.toString().contains(
    'TestWidgetsFlutterBinding',
  );
}
