import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import '../../control/cockpit_command.dart';
import '../../control/cockpit_command_type.dart';
import '../../runtime/cockpit_ui_idle_waiter.dart';
import 'cockpit_command_context.dart';

typedef CockpitRouteTargetsWaiter =
    Future<bool> Function(String? previousRouteName);
typedef CockpitUsesTestBindingProbe = bool Function();

final class CockpitPostActionSettleCoordinator {
  CockpitPostActionSettleCoordinator({
    required CockpitInAppCommandContext context,
    CockpitUsesTestBindingProbe? usesTestBinding,
  }) : _context = context,
       _usesTestBinding = usesTestBinding ?? _defaultUsesTestBinding;

  final CockpitInAppCommandContext _context;
  final CockpitUsesTestBindingProbe _usesTestBinding;

  Future<void> settleBeforeObservation() async {
    await waitForCockpitUiIdle(
      quietWindow: _context.interactionPolicy.uiIdleQuietWindow,
      timeout: _context.interactionPolicy.uiIdleTimeout,
      waitTick: _context.waitTickHandler,
      includeNetworkIdle: false,
    );
  }

  Future<void> bestEffortWaitForUiIdle({
    required bool includeNetworkIdle,
  }) async {
    await waitForCockpitUiIdle(
      quietWindow: _context.interactionPolicy.uiIdleQuietWindow,
      timeout: _context.interactionPolicy.uiIdleTimeout,
      waitTick: _context.waitTickHandler,
      waitForNetworkIdle: _context.waitForNetworkIdleHandler,
      includeNetworkIdle: includeNetworkIdle,
    );
  }

  Future<void> prepareForAction(
    CockpitCommand command, {
    required CockpitCommandType commandType,
  }) async {
    await _context.postActionSettler();
    await settleBeforeObservation();
    await _waitForPreActionContinuity(command, commandType: commandType);
  }

  Future<void> stabilizeAfterAction(
    String? previousRouteName, {
    required CockpitCommandType? commandType,
    required CockpitRouteTargetsWaiter waitForRouteTargets,
  }) async {
    await _context.postActionSettler();
    await _waitForGestureCommit(commandType);
    final routeChanged = await waitForRouteTargets(previousRouteName);
    await settleBeforeObservation();
    await _waitForVisualContinuity(
      commandType: commandType,
      routeChanged: routeChanged,
    );
  }

  Future<void> _waitForGestureCommit(CockpitCommandType? commandType) async {
    if (commandType != CockpitCommandType.tap &&
        commandType != CockpitCommandType.doubleTap &&
        commandType != CockpitCommandType.longPress) {
      return;
    }
    WidgetsBinding widgetsBinding;
    try {
      widgetsBinding = WidgetsBinding.instance;
    } on Object {
      return;
    }
    if (_isTestBinding(widgetsBinding)) {
      return;
    }
    final commitDelay = switch (commandType) {
      CockpitCommandType.longPress => const Duration(milliseconds: 32),
      CockpitCommandType.tap || CockpitCommandType.doubleTap =>
        kDoubleTapTimeout + const Duration(milliseconds: 32),
      _ => Duration.zero,
    };
    if (commitDelay > Duration.zero) {
      await Future<void>.delayed(commitDelay);
    }
  }

  Future<void> _waitForVisualContinuity({
    required CockpitCommandType? commandType,
    required bool routeChanged,
  }) async {
    if (_usesTestBinding() && !_context.hasCustomWaitTickHandler) {
      return;
    }
    final delay = _visualContinuityDelay(
      commandType: commandType,
      routeChanged: routeChanged,
    );
    if (delay <= Duration.zero) {
      return;
    }
    await _context.waitTickHandler(delay);
  }

  Future<void> _waitForPreActionContinuity(
    CockpitCommand command, {
    required CockpitCommandType commandType,
  }) async {
    if (_usesTestBinding() && !_context.hasCustomWaitTickHandler) {
      return;
    }
    final delay = _preActionVisualDelay(command, commandType: commandType);
    if (delay <= Duration.zero) {
      return;
    }
    await _context.waitTickHandler(delay);
  }

  Duration _preActionVisualDelay(
    CockpitCommand command, {
    required CockpitCommandType commandType,
  }) {
    final isVisualMutation = switch (commandType) {
      CockpitCommandType.tap ||
      CockpitCommandType.focusTextInput ||
      CockpitCommandType.setTextEditingValue ||
      CockpitCommandType.sendTextInputAction ||
      CockpitCommandType.doubleTap ||
      CockpitCommandType.longPress ||
      CockpitCommandType.drag ||
      CockpitCommandType.fling ||
      CockpitCommandType.swipe ||
      CockpitCommandType.pinchZoom ||
      CockpitCommandType.rotate ||
      CockpitCommandType.panZoom ||
      CockpitCommandType.multiTouch ||
      CockpitCommandType.scrollUntilVisible ||
      CockpitCommandType.enterText ||
      CockpitCommandType.sendKeyEvent ||
      CockpitCommandType.sendKeyDownEvent ||
      CockpitCommandType.sendKeyUpEvent ||
      CockpitCommandType.showOnScreen ||
      CockpitCommandType.increase ||
      CockpitCommandType.decrease ||
      CockpitCommandType.dismiss ||
      CockpitCommandType.back => true,
      _ => false,
    };
    if (!isVisualMutation) {
      return Duration.zero;
    }
    return _durationFromOptionalPositiveInt(
      command,
      key: 'preActionVisualDelayMs',
      fallback: _context.isRecordingActive()
          ? _maxDuration(
              _context.interactionPolicy.preActionVisualDelay,
              _context.interactionPolicy.recordingPreActionVisualDelay,
            )
          : _context.interactionPolicy.preActionVisualDelay,
    );
  }

  Duration _visualContinuityDelay({
    required CockpitCommandType? commandType,
    required bool routeChanged,
  }) {
    final isVisualMutation = switch (commandType) {
      CockpitCommandType.tap ||
      CockpitCommandType.focusTextInput ||
      CockpitCommandType.setTextEditingValue ||
      CockpitCommandType.sendTextInputAction ||
      CockpitCommandType.doubleTap ||
      CockpitCommandType.longPress ||
      CockpitCommandType.drag ||
      CockpitCommandType.fling ||
      CockpitCommandType.swipe ||
      CockpitCommandType.pinchZoom ||
      CockpitCommandType.rotate ||
      CockpitCommandType.panZoom ||
      CockpitCommandType.multiTouch ||
      CockpitCommandType.scrollUntilVisible ||
      CockpitCommandType.enterText ||
      CockpitCommandType.sendKeyEvent ||
      CockpitCommandType.sendKeyDownEvent ||
      CockpitCommandType.sendKeyUpEvent ||
      CockpitCommandType.showOnScreen ||
      CockpitCommandType.increase ||
      CockpitCommandType.decrease ||
      CockpitCommandType.dismiss ||
      CockpitCommandType.back => true,
      _ => false,
    };
    if (!isVisualMutation && !routeChanged) {
      return Duration.zero;
    }
    if (_context.isRecordingActive()) {
      return routeChanged
          ? _maxDuration(
              _context.interactionPolicy.routeTransitionVisualDelay,
              _context.interactionPolicy.recordingActionVisualDelay,
            )
          : _context.interactionPolicy.recordingActionVisualDelay;
    }
    return routeChanged
        ? _context.interactionPolicy.routeTransitionVisualDelay
        : _context.interactionPolicy.actionVisualDelay;
  }

  Duration _durationFromOptionalPositiveInt(
    CockpitCommand command, {
    required String key,
    required Duration fallback,
  }) {
    final value = command.parameters[key];
    final durationMs = switch (value) {
      int() => value,
      num() => value.toInt(),
      _ => null,
    };
    if (durationMs == null) {
      return fallback;
    }
    if (durationMs <= 0) {
      throw ArgumentError('$key must be positive.');
    }
    return Duration(milliseconds: durationMs);
  }

  Duration _maxDuration(Duration left, Duration right) {
    return left >= right ? left : right;
  }

  static bool _defaultUsesTestBinding() {
    try {
      return _isTestBinding(WidgetsBinding.instance);
    } on Object {
      return false;
    }
  }

  static bool _isTestBinding(WidgetsBinding widgetsBinding) {
    return widgetsBinding.runtimeType.toString().contains(
      'TestWidgetsFlutterBinding',
    );
  }
}
