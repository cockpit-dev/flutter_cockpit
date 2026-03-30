// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../capture/cockpit_capture_result.dart';
import '../capture/cockpit_capture_kind.dart';
import '../capture/cockpit_capture_profile.dart';
import '../control/cockpit_capture_policy.dart';
import '../control/cockpit_command.dart';
import '../control/cockpit_command_execution.dart';
import '../control/cockpit_command_result.dart';
import '../control/cockpit_command_type.dart';
import '../control/cockpit_locator.dart';
import '../control/cockpit_locator_resolution.dart';
import '../control/cockpit_screenshot_request.dart';
import '../errors/cockpit_command_error.dart';
import '../executor/cockpit_command_executor.dart';
import '../executor/in_app/cockpit_capture_orchestrator.dart';
import '../executor/in_app/cockpit_command_context.dart';
import '../executor/in_app/cockpit_command_router.dart';
import '../executor/in_app/cockpit_post_action_settle_coordinator.dart';
import '../gesture/cockpit_gesture_action.dart';
import '../gesture/cockpit_gesture_anchor.dart';
import '../gesture/cockpit_gesture_profile.dart';
import '../gesture/cockpit_multi_touch_sequence.dart';
import '../model/cockpit_artifact_ref.dart';
import '../runtime/cockpit_capabilities.dart';
import '../runtime/cockpit_hit_test_miss_policy.dart';
import '../runtime/cockpit_interaction_policy.dart';
import '../runtime/cockpit_reveal_alignment.dart';
import '../runtime/cockpit_snapshot.dart';
import '../runtime/cockpit_snapshot_options.dart';
import '../runtime/cockpit_target.dart';
import '../runtime/cockpit_target_geometry_resolver.dart';
import '../runtime/cockpit_target_hit_test_inspector.dart';
import '../runtime/cockpit_target_registry.dart';
import '../runtime/cockpit_ui_idle_waiter.dart';
import '../runtime/cockpit_key_event_request.dart';
import '../runtime/cockpit_text_input_request.dart';

final class InAppCockpitCommandExecutor implements CockpitCommandExecutor {
  InAppCockpitCommandExecutor({
    required CockpitTargetRegistry registry,
    CockpitCaptureHandler? captureHandler,
    CockpitSnapshotProvider? snapshotProvider,
    CockpitPostActionSettler? postActionSettler,
    CockpitScrollStepHandler? scrollStepHandler,
    CockpitEnsureVisibleHandler? ensureVisibleHandler,
    CockpitGestureHandler? gestureHandler,
    CockpitNetworkActivityClearer? clearNetworkActivityHandler,
    CockpitNetworkIdleWaiter? waitForNetworkIdleHandler,
    CockpitBackNavigationHandler? backNavigationHandler,
    CockpitWaitTickHandler? waitTickHandler,
    CockpitKeyEventHandler? keyEventHandler,
    CockpitInteractionPolicy interactionPolicy =
        const CockpitInteractionPolicy(),
    CockpitRecordingActivityProbe? isRecordingActive,
    String platform = 'flutter',
    String transportType = 'inApp',
  }) : _context = CockpitInAppCommandContext(
          registry: registry,
          captureHandler: captureHandler,
          snapshotProvider:
              snapshotProvider ?? _defaultSnapshotProvider(registry),
          postActionSettler: postActionSettler ?? _defaultPostActionSettler,
          scrollStepHandler: scrollStepHandler,
          ensureVisibleHandler: ensureVisibleHandler,
          gestureHandler: gestureHandler,
          clearNetworkActivityHandler: clearNetworkActivityHandler,
          waitForNetworkIdleHandler: waitForNetworkIdleHandler,
          backNavigationHandler: backNavigationHandler,
          hasCustomWaitTickHandler: waitTickHandler != null,
          waitTickHandler: waitTickHandler ?? _defaultWaitTickHandler,
          keyEventHandler: keyEventHandler ?? _defaultKeyEventHandler,
          interactionPolicy: interactionPolicy,
          isRecordingActive:
              isRecordingActive ?? _defaultRecordingActivityProbe,
          platform: platform,
          transportType: transportType,
        ) {
    _settleCoordinator = CockpitPostActionSettleCoordinator(context: _context);
    _captureOrchestrator = CockpitCaptureOrchestrator(
      captureHandler: _context.captureHandler,
      postActionSettler: _context.postActionSettler,
      settleBeforeObservation: _settleCoordinator.settleBeforeObservation,
      bestEffortWaitForUiIdle: ({required includeNetworkIdleValue}) {
        return _settleCoordinator.bestEffortWaitForUiIdle(
          includeNetworkIdle: includeNetworkIdleValue,
        );
      },
      defaultSnapshotOptionsForReason: _defaultSnapshotOptionsForReason,
    );
    _commandRouter = CockpitCommandRouter(handlers: _buildCommandHandlers());
  }

  final CockpitInAppCommandContext _context;
  late final CockpitPostActionSettleCoordinator _settleCoordinator;
  late final CockpitCaptureOrchestrator _captureOrchestrator;
  late final CockpitCommandRouter _commandRouter;

  CockpitTargetRegistry get _registry => _context.registry;
  CockpitCaptureHandler? get _captureHandler => _context.captureHandler;
  CockpitSnapshotProvider get _snapshotProvider => _context.snapshotProvider;
  CockpitPostActionSettler get _postActionSettler => _context.postActionSettler;
  CockpitScrollStepHandler? get _scrollStepHandler =>
      _context.scrollStepHandler;
  CockpitEnsureVisibleHandler? get _ensureVisibleHandler =>
      _context.ensureVisibleHandler;
  CockpitGestureHandler? get _gestureHandler => _context.gestureHandler;
  CockpitNetworkActivityClearer? get _clearNetworkActivityHandler =>
      _context.clearNetworkActivityHandler;
  CockpitNetworkIdleWaiter? get _waitForNetworkIdleHandler =>
      _context.waitForNetworkIdleHandler;
  CockpitBackNavigationHandler? get _backNavigationHandler =>
      _context.backNavigationHandler;
  bool get _hasCustomWaitTickHandler => _context.hasCustomWaitTickHandler;
  CockpitWaitTickHandler get _waitTickHandler => _context.waitTickHandler;
  CockpitKeyEventHandler get _keyEventHandler => _context.keyEventHandler;
  CockpitInteractionPolicy get _interactionPolicy => _context.interactionPolicy;
  CockpitRecordingActivityProbe get _isRecordingActive =>
      _context.isRecordingActive;
  String get _platform => _context.platform;
  String get _transportType => _context.transportType;

  @override
  Future<CockpitCapabilities> describeCapabilities() async {
    final supportedCommands = <CockpitCommandType>{
      CockpitCommandType.tap,
      CockpitCommandType.enterText,
      CockpitCommandType.focusTextInput,
      CockpitCommandType.setTextEditingValue,
      CockpitCommandType.sendTextInputAction,
      CockpitCommandType.sendKeyEvent,
      CockpitCommandType.sendKeyDownEvent,
      CockpitCommandType.sendKeyUpEvent,
      CockpitCommandType.showOnScreen,
      CockpitCommandType.increase,
      CockpitCommandType.decrease,
      CockpitCommandType.dismiss,
      CockpitCommandType.longPress,
      CockpitCommandType.doubleTap,
      if (_gestureHandler != null) ...<CockpitCommandType>{
        CockpitCommandType.drag,
        CockpitCommandType.fling,
        CockpitCommandType.swipe,
        CockpitCommandType.pinchZoom,
        CockpitCommandType.rotate,
        CockpitCommandType.panZoom,
        CockpitCommandType.multiTouch,
      },
      if (_scrollStepHandler != null) CockpitCommandType.scrollUntilVisible,
      if (_clearNetworkActivityHandler != null)
        CockpitCommandType.clearNetworkActivity,
      if (_waitForNetworkIdleHandler != null)
        CockpitCommandType.waitForNetworkIdle,
      CockpitCommandType.waitForUiIdle,
      if (_backNavigationHandler != null) CockpitCommandType.back,
      CockpitCommandType.assertVisible,
      CockpitCommandType.assertText,
      CockpitCommandType.waitFor,
      CockpitCommandType.collectSnapshot,
      if (_captureHandler != null) CockpitCommandType.captureScreenshot,
    };

    return CockpitCapabilities(
      platform: _platform,
      transportType: _transportType,
      supportsInAppControl: true,
      supportsFlutterViewCapture: _captureHandler != null,
      supportsNativeScreenCapture: false,
      supportsHostAutomation: false,
      supportedCommands: supportedCommands.toList(growable: false),
      supportedLocatorStrategies: CockpitLocatorKind.values,
    );
  }

  @override
  Future<CockpitCommandResult> execute(CockpitCommand command) async {
    return (await executeWithArtifacts(command)).result;
  }

  Future<CockpitCommandExecution> executeWithArtifacts(
    CockpitCommand command,
  ) async {
    final stopwatch = Stopwatch()..start();

    try {
      return await _commandRouter.execute(command, stopwatch);
    } finally {
      stopwatch.stop();
    }
  }

  Map<CockpitCommandType, CockpitInAppCommandHandler> _buildCommandHandlers() {
    return <CockpitCommandType, CockpitInAppCommandHandler>{
      CockpitCommandType.tap: _executeTap,
      CockpitCommandType.enterText: _executeEnterText,
      CockpitCommandType.focusTextInput: _executeFocusTextInput,
      CockpitCommandType.setTextEditingValue: _executeSetTextEditingValue,
      CockpitCommandType.sendTextInputAction: _executeSendTextInputAction,
      CockpitCommandType.sendKeyEvent: _executeKeyEvent,
      CockpitCommandType.sendKeyDownEvent: _executeKeyEvent,
      CockpitCommandType.sendKeyUpEvent: _executeKeyEvent,
      CockpitCommandType.longPress: _executeLongPress,
      CockpitCommandType.doubleTap: _executeDoubleTap,
      CockpitCommandType.drag: _executeDrag,
      CockpitCommandType.fling: _executeFling,
      CockpitCommandType.swipe: _executeSwipe,
      CockpitCommandType.pinchZoom: _executePinchZoom,
      CockpitCommandType.rotate: _executeRotate,
      CockpitCommandType.panZoom: _executePanZoom,
      CockpitCommandType.multiTouch: _executeMultiTouch,
      CockpitCommandType.scrollUntilVisible: _executeScrollUntilVisible,
      CockpitCommandType.clearNetworkActivity: (command, stopwatch) async =>
          _executeClearNetworkActivity(command, stopwatch),
      CockpitCommandType.waitForNetworkIdle: _executeWaitForNetworkIdle,
      CockpitCommandType.waitForUiIdle: _executeWaitForUiIdle,
      CockpitCommandType.back: _executeBack,
      CockpitCommandType.showOnScreen: (command, stopwatch) {
        return _executeSemanticAction(
          command,
          stopwatch,
          requiredCommand: CockpitCommandType.showOnScreen,
          semanticAction: (target) => target.onSemanticShowOnScreen,
        );
      },
      CockpitCommandType.increase: (command, stopwatch) {
        return _executeSemanticAction(
          command,
          stopwatch,
          requiredCommand: CockpitCommandType.increase,
          semanticAction: (target) => target.onSemanticIncrease,
        );
      },
      CockpitCommandType.decrease: (command, stopwatch) {
        return _executeSemanticAction(
          command,
          stopwatch,
          requiredCommand: CockpitCommandType.decrease,
          semanticAction: (target) => target.onSemanticDecrease,
        );
      },
      CockpitCommandType.dismiss: (command, stopwatch) {
        return _executeSemanticAction(
          command,
          stopwatch,
          requiredCommand: CockpitCommandType.dismiss,
          semanticAction: (target) => target.onSemanticDismiss,
        );
      },
      CockpitCommandType.assertVisible: _executeAssertVisible,
      CockpitCommandType.assertText: _executeAssertText,
      CockpitCommandType.waitFor: _executeWaitFor,
      CockpitCommandType.collectSnapshot: (command, stopwatch) async {
        return _successExecution(
          command: command,
          durationMs: stopwatch.elapsedMilliseconds,
          snapshot: _snapshotProvider(
            options: command.snapshotOptions ??
                const CockpitSnapshotOptions.baseline(),
          ).toJson(),
        );
      },
      CockpitCommandType.captureScreenshot: _executeCaptureScreenshot,
    };
  }

  Future<CockpitCommandExecution> _executeTap(
    CockpitCommand command,
    Stopwatch stopwatch,
  ) async {
    final previousRouteName = _liveSnapshot().routeName;
    final coordinateOrigin = _pointParameter(command);
    if (command.locator == null && coordinateOrigin != null) {
      return _executeResolvedGesture(
        command: command,
        stopwatch: stopwatch,
        resolution: null,
        actionBuilder: () => CockpitGestureAction.tap(
          origin: coordinateOrigin,
          anchor: _gestureAnchorParameter(command),
          pointerDeviceKind: _pointerDeviceKindParameter(command),
          buttons: _buttonsParameter(command),
        ),
      );
    }
    final resolution = await _resolveWithRetry(command);
    if (!resolution.isSuccess) {
      return _failureExecution(
        command: command,
        durationMs: stopwatch.elapsedMilliseconds,
        snapshot: _liveSnapshot().toJson(),
        error: resolution.error!,
      );
    }

    final target = resolution.target!;
    if (target.supportedCommands.contains(CockpitCommandType.tap) &&
        target.onTap != null) {
      await _prepareForAction(command, commandType: CockpitCommandType.tap);
      target.onTap!.call();
      await _stabilizeAfterAction(
        previousRouteName,
        commandType: CockpitCommandType.tap,
      );

      return _buildSuccessWithOptionalCapture(
        command: command,
        resolution: resolution,
        durationMs: stopwatch.elapsedMilliseconds,
      );
    }
    if (target.supportedCommands.contains(CockpitCommandType.tap) &&
        target.onSemanticTap != null) {
      await _prepareForAction(command, commandType: CockpitCommandType.tap);
      target.onSemanticTap!.call();
      await _stabilizeAfterAction(
        previousRouteName,
        commandType: CockpitCommandType.tap,
      );
      return _buildSuccessWithOptionalCapture(
        command: command,
        resolution: resolution,
        durationMs: stopwatch.elapsedMilliseconds,
      );
    }
    if (_gestureHandler != null) {
      final gestureResult = await _executeGestureAction(
        command: command,
        stopwatch: stopwatch,
        resolution: resolution,
        action: CockpitGestureAction.tap(
          target: target,
          anchor: _gestureAnchorParameter(command),
          pointerDeviceKind: _pointerDeviceKindParameter(command),
          buttons: _buttonsParameter(command),
        ),
        previousRouteName: previousRouteName,
      );
      if (gestureResult != null) {
        return gestureResult;
      }
    }
    return _unsupportedExecution(
      command: command,
      durationMs: stopwatch.elapsedMilliseconds,
      target: target,
    );
  }

  Future<CockpitCommandExecution> _executeLongPress(
    CockpitCommand command,
    Stopwatch stopwatch,
  ) async {
    final previousRouteName = _liveSnapshot().routeName;
    final coordinateOrigin = _pointParameter(command);
    if (command.locator == null && coordinateOrigin != null) {
      return _executeResolvedGesture(
        command: command,
        stopwatch: stopwatch,
        resolution: null,
        actionBuilder: () => CockpitGestureAction.longPress(
          origin: coordinateOrigin,
          anchor: _gestureAnchorParameter(command),
          duration: _durationParameter(
            command,
            key: 'durationMs',
            fallbackMs: (kLongPressTimeout + kPressTimeout).inMilliseconds,
          ),
          pointerDeviceKind: _pointerDeviceKindParameter(command),
          buttons: _buttonsParameter(command),
        ),
      );
    }
    if (command.locator == null) {
      return _failureExecution(
        command: command,
        durationMs: stopwatch.elapsedMilliseconds,
        error: CockpitCommandError.invalidGestureParameters(
          message:
              'longPress requires either a locator or explicit coordinates.',
        ),
      );
    }
    final resolution = await _resolveWithRetry(command);
    if (!resolution.isSuccess) {
      return _failureExecution(
        command: command,
        durationMs: stopwatch.elapsedMilliseconds,
        snapshot: _liveSnapshot().toJson(),
        error: resolution.error!,
      );
    }
    final target = resolution.target!;
    if (target.supportedCommands.contains(CockpitCommandType.longPress) &&
        target.onSemanticLongPress != null) {
      await _prepareForAction(
        command,
        commandType: CockpitCommandType.longPress,
      );
      target.onSemanticLongPress!.call();
      await _stabilizeAfterAction(
        previousRouteName,
        commandType: CockpitCommandType.longPress,
      );
      return _buildSuccessWithOptionalCapture(
        command: command,
        resolution: resolution,
        durationMs: stopwatch.elapsedMilliseconds,
      );
    }
    if (target.supportedCommands.contains(CockpitCommandType.longPress) &&
        target.onLongPress != null) {
      await _prepareForAction(
        command,
        commandType: CockpitCommandType.longPress,
      );
      target.onLongPress!.call();
      await _stabilizeAfterAction(
        previousRouteName,
        commandType: CockpitCommandType.longPress,
      );
      return _buildSuccessWithOptionalCapture(
        command: command,
        resolution: resolution,
        durationMs: stopwatch.elapsedMilliseconds,
      );
    }
    return _executeResolvedGesture(
      command: command,
      stopwatch: stopwatch,
      resolution: resolution,
      actionBuilder: () => CockpitGestureAction.longPress(
        target: target,
        anchor: _gestureAnchorParameter(command),
        duration: _durationParameter(
          command,
          key: 'durationMs',
          fallbackMs: (kLongPressTimeout + kPressTimeout).inMilliseconds,
        ),
        pointerDeviceKind: _pointerDeviceKindParameter(command),
        buttons: _buttonsParameter(command),
      ),
    );
  }

  Future<CockpitCommandExecution> _executeDoubleTap(
    CockpitCommand command,
    Stopwatch stopwatch,
  ) async {
    final previousRouteName = _liveSnapshot().routeName;
    final coordinateOrigin = _pointParameter(command);
    if (command.locator == null && coordinateOrigin != null) {
      return _executeResolvedGesture(
        command: command,
        stopwatch: stopwatch,
        resolution: null,
        actionBuilder: () => CockpitGestureAction.doubleTap(
          origin: coordinateOrigin,
          anchor: _gestureAnchorParameter(command),
          interval: _durationParameter(
            command,
            key: 'intervalMs',
            fallbackMs: 90,
          ),
          pointerDeviceKind: _pointerDeviceKindParameter(command),
          buttons: _buttonsParameter(command),
        ),
      );
    }
    if (command.locator == null) {
      return _failureExecution(
        command: command,
        durationMs: stopwatch.elapsedMilliseconds,
        error: CockpitCommandError.invalidGestureParameters(
          message:
              'doubleTap requires either a locator or explicit coordinates.',
        ),
      );
    }
    final resolution = await _resolveWithRetry(command);
    if (!resolution.isSuccess) {
      return _failureExecution(
        command: command,
        durationMs: stopwatch.elapsedMilliseconds,
        snapshot: _liveSnapshot().toJson(),
        error: resolution.error!,
      );
    }
    final target = resolution.target!;
    if (target.supportedCommands.contains(CockpitCommandType.doubleTap) &&
        target.onDoubleTap != null) {
      await _prepareForAction(
        command,
        commandType: CockpitCommandType.doubleTap,
      );
      target.onDoubleTap!.call();
      await _stabilizeAfterAction(
        previousRouteName,
        commandType: CockpitCommandType.doubleTap,
      );
      return _buildSuccessWithOptionalCapture(
        command: command,
        resolution: resolution,
        durationMs: stopwatch.elapsedMilliseconds,
      );
    }
    return _executeResolvedGesture(
      command: command,
      stopwatch: stopwatch,
      resolution: resolution,
      actionBuilder: () => CockpitGestureAction.doubleTap(
        target: target,
        anchor: _gestureAnchorParameter(command),
        interval: _durationParameter(
          command,
          key: 'intervalMs',
          fallbackMs: 90,
        ),
        pointerDeviceKind: _pointerDeviceKindParameter(command),
        buttons: _buttonsParameter(command),
      ),
    );
  }

  Future<CockpitCommandExecution> _executeDrag(
    CockpitCommand command,
    Stopwatch stopwatch,
  ) async {
    final dx = _doubleParameter(command, 'dx');
    final dy = _doubleParameter(command, 'dy');
    if (dx == null || dy == null) {
      return _failureExecution(
        command: command,
        durationMs: stopwatch.elapsedMilliseconds,
        error: CockpitCommandError.invalidGestureParameters(
          message: 'drag requires numeric dx and dy parameters.',
        ),
      );
    }

    return _executeOptionalTargetGesture(
      command: command,
      stopwatch: stopwatch,
      actionBuilder: (target) => _buildDirectionalGesture(
        command: command,
        target: target,
        delta: Offset(dx, dy),
        duration: _durationParameter(
          command,
          key: 'durationMs',
          fallbackMs: 220,
        ),
        holdDuration: _optionalDurationParameter(command, 'holdDurationMs'),
        touchSlopX: _doubleParameter(command, 'touchSlopX') ??
            cockpitDefaultDragTouchSlop,
        touchSlopY: _doubleParameter(command, 'touchSlopY') ??
            cockpitDefaultDragTouchSlop,
        moveEventCount: _intParameter(command, 'moveEventCount') ?? 0,
        fallbackType: CockpitCommandType.drag,
      ),
    );
  }

  Future<CockpitCommandExecution> _executeSwipe(
    CockpitCommand command,
    Stopwatch stopwatch,
  ) async {
    final direction = _axisDirectionParameter(command.parameters['direction']);
    if (direction == null) {
      return _failureExecution(
        command: command,
        durationMs: stopwatch.elapsedMilliseconds,
        error: CockpitCommandError.invalidGestureParameters(
          message: 'swipe requires direction: up, down, left, or right.',
        ),
      );
    }

    return _executeOptionalTargetGesture(
      command: command,
      stopwatch: stopwatch,
      actionBuilder: (target) => _buildSwipeGesture(
        command: command,
        target: target,
        direction: direction,
        distanceFactor: (_doubleParameter(command, 'distanceFactor') ?? 0.82)
            .clamp(0.15, 0.95),
        duration: _durationParameter(
          command,
          key: 'durationMs',
          fallbackMs: 200,
        ),
        moveEventCount: _intParameter(command, 'moveEventCount') ?? 0,
      ),
    );
  }

  Future<CockpitCommandExecution> _executeFling(
    CockpitCommand command,
    Stopwatch stopwatch,
  ) async {
    final dx = _doubleParameter(command, 'dx');
    final dy = _doubleParameter(command, 'dy');
    if (dx == null || dy == null) {
      return _failureExecution(
        command: command,
        durationMs: stopwatch.elapsedMilliseconds,
        error: CockpitCommandError.invalidGestureParameters(
          message: 'fling requires numeric dx and dy parameters.',
        ),
      );
    }

    return _executeOptionalTargetGesture(
      command: command,
      stopwatch: stopwatch,
      actionBuilder: (target) => _buildDirectionalGesture(
        command: command,
        target: target,
        delta: Offset(dx, dy),
        duration: _durationParameter(
          command,
          key: 'durationMs',
          fallbackMs: 96,
        ),
        moveEventCount: _intParameter(command, 'moveEventCount') ?? 50,
        fallbackType: CockpitCommandType.fling,
      ),
    );
  }

  Future<CockpitCommandExecution> _executePinchZoom(
    CockpitCommand command,
    Stopwatch stopwatch,
  ) async {
    final scale = _doubleParameter(command, 'scale');
    if (scale == null || scale <= 0) {
      return _failureExecution(
        command: command,
        durationMs: stopwatch.elapsedMilliseconds,
        error: CockpitCommandError.invalidGestureParameters(
          message: 'pinchZoom requires a positive scale parameter.',
        ),
      );
    }

    return _executeOptionalTargetGesture(
      command: command,
      stopwatch: stopwatch,
      actionBuilder: (target) => _buildPinchZoomGesture(
        command: command,
        target: target,
        scale: scale,
        startSpan: _doubleParameter(command, 'startSpan') ?? 56,
        duration: _durationParameter(
          command,
          key: 'durationMs',
          fallbackMs: 220,
        ),
        moveEventCount: _intParameter(command, 'moveEventCount') ?? 0,
      ),
    );
  }

  Future<CockpitCommandExecution> _executeRotate(
    CockpitCommand command,
    Stopwatch stopwatch,
  ) async {
    final rotation = _doubleParameter(command, 'rotationRadians');
    if (rotation == null || rotation == 0) {
      return _failureExecution(
        command: command,
        durationMs: stopwatch.elapsedMilliseconds,
        error: CockpitCommandError.invalidGestureParameters(
          message: 'rotate requires a non-zero rotationRadians parameter.',
        ),
      );
    }

    return _executeOptionalTargetGesture(
      command: command,
      stopwatch: stopwatch,
      actionBuilder: (target) => _buildRotateGesture(
        command: command,
        target: target,
        rotation: rotation,
        startSpan: _doubleParameter(command, 'startSpan') ?? 56,
        duration: _durationParameter(
          command,
          key: 'durationMs',
          fallbackMs: 220,
        ),
        moveEventCount: _intParameter(command, 'moveEventCount') ?? 0,
      ),
    );
  }

  Future<CockpitCommandExecution> _executePanZoom(
    CockpitCommand command,
    Stopwatch stopwatch,
  ) async {
    final scale = _doubleParameter(command, 'scale') ?? 1.0;
    final rotation = _doubleParameter(command, 'rotationRadians') ?? 0.0;
    final panDx = _doubleParameter(command, 'panDx') ?? 0.0;
    final panDy = _doubleParameter(command, 'panDy') ?? 0.0;
    if (scale <= 0) {
      return _failureExecution(
        command: command,
        durationMs: stopwatch.elapsedMilliseconds,
        error: CockpitCommandError.invalidGestureParameters(
          message: 'panZoom requires a positive scale parameter.',
        ),
      );
    }
    if (scale == 1.0 && rotation == 0.0 && panDx == 0.0 && panDy == 0.0) {
      return _failureExecution(
        command: command,
        durationMs: stopwatch.elapsedMilliseconds,
        error: CockpitCommandError.invalidGestureParameters(
          message:
              'panZoom requires pan, scale, or rotation parameters to change.',
        ),
      );
    }

    return _executeOptionalTargetGesture(
      command: command,
      stopwatch: stopwatch,
      actionBuilder: (target) => CockpitGestureAction.panZoom(
        target: target,
        origin: _pointParameter(command),
        anchor: _gestureAnchorParameter(command),
        delta: Offset(panDx, panDy),
        scale: scale,
        rotation: rotation,
        duration: _durationParameter(
          command,
          key: 'durationMs',
          fallbackMs: 180,
        ),
        moveEventCount: _intParameter(command, 'moveEventCount') ?? 0,
      ),
    );
  }

  Future<CockpitCommandExecution> _executeMultiTouch(
    CockpitCommand command,
    Stopwatch stopwatch,
  ) async {
    final rawSequence = command.parameters['sequence'];
    final sequence = switch (rawSequence) {
      CockpitMultiTouchSequence() => rawSequence,
      Map<Object?, Object?>() => CockpitMultiTouchSequence.fromJson(
          Map<String, Object?>.from(rawSequence),
        ),
      _ => null,
    };
    if (sequence == null) {
      return _failureExecution(
        command: command,
        durationMs: stopwatch.elapsedMilliseconds,
        error: CockpitCommandError.invalidGestureParameters(
          message: 'multiTouch requires a valid sequence payload.',
        ),
      );
    }

    return _executeOptionalTargetGesture(
      command: command,
      stopwatch: stopwatch,
      actionBuilder: (target) => CockpitGestureAction.multiTouch(
        target: target,
        origin: _pointParameter(command),
        anchor: _gestureAnchorParameter(command),
        sequence: sequence,
      ),
    );
  }

  Future<CockpitCommandExecution> _executeScrollUntilVisible(
    CockpitCommand command,
    Stopwatch stopwatch,
  ) async {
    final scrollStepHandler = _scrollStepHandler;
    if (scrollStepHandler == null) {
      return _failureExecution(
        command: command,
        durationMs: stopwatch.elapsedMilliseconds,
        error: CockpitCommandError.unsupportedCapability(
          message: 'Scrolling is not available for this executor.',
        ),
      );
    }

    final locator = command.locator;
    if (locator == null) {
      return _failureExecution(
        command: command,
        durationMs: stopwatch.elapsedMilliseconds,
        error: CockpitCommandError.assertionFailed(
          message: 'scrollUntilVisible requires a locator.',
        ),
      );
    }

    final maxScrolls = _intParameter(command, 'maxScrolls') ?? 12;
    final viewportFraction =
        _doubleParameter(command, 'viewportFraction') ?? 0.8;
    final reverse = command.parameters['reverse'] == true;
    final scrollableKey = _stringParameter(command, 'scrollableKey');
    final durationPerStep = _durationFromOptionalPositiveInt(
      command,
      key: 'durationPerStepMs',
      fallback: const Duration(milliseconds: 220),
    );
    final gestureProfile = _gestureProfileParameter(command);
    final continuous = _boolParameter(command, 'continuous') ?? false;
    final postScrollEnsureVisible =
        _boolParameter(command, 'postScrollEnsureVisible') ?? true;
    final revealAlignment =
        _revealAlignmentParameter(command) ?? CockpitRevealAlignment.nearest;
    final revealPadding = (_doubleParameter(command, 'revealPaddingPx') ?? 0)
        .clamp(0, 240)
        .toDouble();
    final explicitRevealRequested =
        revealAlignment != CockpitRevealAlignment.nearest || revealPadding > 0;

    final initialSatisfied = _scrollLocatorResolution(command);
    if (initialSatisfied != null) {
      if (explicitRevealRequested) {
        await _attemptEnsureVisible(
          locator,
          durationPerStep,
          alignment: revealAlignment,
          padding: revealPadding,
        );
        await _postActionSettler();
        await _settleBeforeObservation();
      }
      return _successExecution(
        command: command,
        durationMs: stopwatch.elapsedMilliseconds,
        locatorResolution: initialSatisfied,
        snapshot: _liveSnapshot().toJson(),
      );
    }

    final allowsGenericResolution = _allowsGenericScrollResolution(locator);
    var resolution = allowsGenericResolution
        ? await _resolveWithRetry(command)
        : _resolve(command);
    if (allowsGenericResolution && resolution.isSuccess) {
      if (explicitRevealRequested) {
        await _attemptEnsureVisible(
          locator,
          durationPerStep,
          alignment: revealAlignment,
          padding: revealPadding,
        );
        await _postActionSettler();
        await _settleBeforeObservation();
      }
      return _successExecution(
        command: command,
        durationMs: stopwatch.elapsedMilliseconds,
        locatorResolution: resolution.locatorResolution,
        snapshot: _liveSnapshot().toJson(),
      );
    }

    if (await _attemptEnsureVisible(
      locator,
      durationPerStep,
      alignment: revealAlignment,
      padding: revealPadding,
    )) {
      await _postActionSettler();
      await _settleBeforeObservation();
      await _waitForVisualContinuity(
        commandType: CockpitCommandType.scrollUntilVisible,
        routeChanged: false,
      );
      resolution = allowsGenericResolution
          ? await _resolveWithRetry(command, attempts: 2)
          : _resolve(command);
      if (resolution.isSuccess) {
        return _successExecution(
          command: command,
          durationMs: stopwatch.elapsedMilliseconds,
          locatorResolution: resolution.locatorResolution,
          snapshot: _liveSnapshot().toJson(),
        );
      }
    }

    for (var attempt = 0; attempt < maxScrolls; attempt += 1) {
      await _prepareForAction(
        command,
        commandType: CockpitCommandType.scrollUntilVisible,
      );
      final didScroll = await scrollStepHandler(
        reverse: reverse,
        viewportFraction: viewportFraction,
        scrollableKey: scrollableKey,
        duration: durationPerStep,
        gestureProfile: gestureProfile,
        continuous: continuous,
        postScrollEnsureVisible: postScrollEnsureVisible,
      );
      if (!didScroll) {
        break;
      }

      await _postActionSettler();
      await _settleBeforeObservation();
      await _waitForVisualContinuity(
        commandType: CockpitCommandType.scrollUntilVisible,
        routeChanged: false,
      );

      final satisfied = _scrollLocatorResolution(command);
      if (satisfied != null) {
        return _successExecution(
          command: command,
          durationMs: stopwatch.elapsedMilliseconds,
          locatorResolution: satisfied,
          snapshot: _liveSnapshot().toJson(),
        );
      }

      resolution = allowsGenericResolution
          ? await _resolveWithRetry(command, attempts: 2)
          : _resolve(command);
      if (allowsGenericResolution && resolution.isSuccess) {
        return _successExecution(
          command: command,
          durationMs: stopwatch.elapsedMilliseconds,
          locatorResolution: resolution.locatorResolution,
          snapshot: _liveSnapshot().toJson(),
        );
      }
      if (await _attemptEnsureVisible(
        locator,
        durationPerStep,
        alignment: revealAlignment,
        padding: revealPadding,
      )) {
        await _postActionSettler();
        await _settleBeforeObservation();
        await _waitForVisualContinuity(
          commandType: CockpitCommandType.scrollUntilVisible,
          routeChanged: false,
        );
        resolution = allowsGenericResolution
            ? await _resolveWithRetry(command, attempts: 2)
            : _resolve(command);
        if (resolution.isSuccess) {
          return _successExecution(
            command: command,
            durationMs: stopwatch.elapsedMilliseconds,
            locatorResolution: resolution.locatorResolution,
            snapshot: _liveSnapshot().toJson(),
          );
        }
      }
      if (resolution.error?.code == CockpitCommandError.ambiguousTargetCode) {
        return _failureExecution(
          command: command,
          durationMs: stopwatch.elapsedMilliseconds,
          snapshot: _liveSnapshot().toJson(),
          error: resolution.error!,
        );
      }
    }

    return _failureExecution(
      command: command,
      durationMs: stopwatch.elapsedMilliseconds,
      snapshot: _liveSnapshot().toJson(),
      error: resolution.error ??
          CockpitCommandError.targetNotFound(
            message: 'No visible target matched after scrolling.',
            details: <String, Object?>{
              'requestedLocator': locator.toJson(),
              'maxScrolls': maxScrolls,
              'reverse': reverse,
              'viewportFraction': viewportFraction,
              'scrollableKey': scrollableKey,
              'durationPerStepMs': durationPerStep.inMilliseconds,
              'gestureProfile': gestureProfile.name,
              'continuous': continuous,
              'postScrollEnsureVisible': postScrollEnsureVisible,
              'revealAlignment': revealAlignment.name,
              'revealPaddingPx': revealPadding,
            },
          ),
    );
  }

  Future<bool> _attemptEnsureVisible(
    CockpitLocator locator,
    Duration duration, {
    required CockpitRevealAlignment alignment,
    required double padding,
  }) async {
    final ensureVisibleHandler = _ensureVisibleHandler;
    if (ensureVisibleHandler == null) {
      return false;
    }
    return ensureVisibleHandler(
      locator: locator,
      duration: duration,
      alignment: alignment,
      padding: padding,
    );
  }

  CockpitCommandExecution _executeClearNetworkActivity(
    CockpitCommand command,
    Stopwatch stopwatch,
  ) {
    final clearNetworkActivityHandler = _clearNetworkActivityHandler;
    if (clearNetworkActivityHandler == null) {
      return _failureExecution(
        command: command,
        durationMs: stopwatch.elapsedMilliseconds,
        error: CockpitCommandError.unsupportedCapability(
          message:
              'Network activity capture is not available for this executor.',
        ),
      );
    }

    clearNetworkActivityHandler();
    return _successExecution(
      command: command,
      durationMs: stopwatch.elapsedMilliseconds,
      snapshot: _liveSnapshot().toJson(),
    );
  }

  Future<CockpitCommandExecution> _executeWaitForNetworkIdle(
    CockpitCommand command,
    Stopwatch stopwatch,
  ) async {
    final waitForNetworkIdleHandler = _waitForNetworkIdleHandler;
    if (waitForNetworkIdleHandler == null) {
      return _failureExecution(
        command: command,
        durationMs: stopwatch.elapsedMilliseconds,
        error: CockpitCommandError.unsupportedCapability(
          message: 'Network idle waiting is not available for this executor.',
        ),
      );
    }

    final quietWindow = _durationFromOptionalPositiveInt(
      command,
      key: 'quietWindowMs',
      fallback: const Duration(milliseconds: 150),
    );
    final timeout = _durationFromOptionalPositiveInt(
      command,
      key: 'timeoutMs',
      fallback: Duration(milliseconds: command.timeoutMs ?? 2000),
    );
    final didGoIdle = await waitForNetworkIdleHandler(
      quietWindow: quietWindow,
      timeout: timeout,
    );
    if (!didGoIdle) {
      return _failureExecution(
        command: command,
        durationMs: stopwatch.elapsedMilliseconds,
        snapshot: _liveSnapshot().toJson(),
        error: CockpitCommandError.timeout(
          message: 'Timed out waiting for network to go idle.',
          details: <String, Object?>{
            'quietWindowMs': quietWindow.inMilliseconds,
            'timeoutMs': timeout.inMilliseconds,
          },
        ),
      );
    }

    return _successExecution(
      command: command,
      durationMs: stopwatch.elapsedMilliseconds,
      snapshot: _liveSnapshot().toJson(),
    );
  }

  Future<CockpitCommandExecution> _executeWaitForUiIdle(
    CockpitCommand command,
    Stopwatch stopwatch,
  ) async {
    final quietWindow = _durationFromOptionalPositiveInt(
      command,
      key: 'quietWindowMs',
      fallback: _interactionPolicy.uiIdleQuietWindow,
    );
    final timeout = _durationFromOptionalPositiveInt(
      command,
      key: 'timeoutMs',
      fallback: Duration(milliseconds: command.timeoutMs ?? 2000),
    );
    final includeNetworkIdle =
        _boolParameter(command, 'includeNetworkIdle') ?? true;
    final didGoIdle = await waitForCockpitUiIdle(
      quietWindow: quietWindow,
      timeout: timeout,
      waitTick: _waitTickHandler,
      waitForNetworkIdle: _waitForNetworkIdleHandler,
      includeNetworkIdle: includeNetworkIdle,
    );
    if (!didGoIdle) {
      return _failureExecution(
        command: command,
        durationMs: stopwatch.elapsedMilliseconds,
        snapshot: _liveSnapshot().toJson(),
        error: CockpitCommandError.timeout(
          message: 'Timed out waiting for the app to go quiet.',
          details: <String, Object?>{
            'quietWindowMs': quietWindow.inMilliseconds,
            'timeoutMs': timeout.inMilliseconds,
            'includeNetworkIdle': includeNetworkIdle,
          },
        ),
      );
    }

    return _successExecution(
      command: command,
      durationMs: stopwatch.elapsedMilliseconds,
      snapshot: _liveSnapshot().toJson(),
    );
  }

  Future<CockpitCommandExecution> _executeBack(
    CockpitCommand command,
    Stopwatch stopwatch,
  ) async {
    final backNavigationHandler = _backNavigationHandler;
    if (backNavigationHandler == null) {
      return _failureExecution(
        command: command,
        durationMs: stopwatch.elapsedMilliseconds,
        error: CockpitCommandError.unsupportedCapability(
          message: 'Back navigation is not available for this executor.',
        ),
      );
    }

    final previousRouteName = _liveSnapshot().routeName;
    await _prepareForAction(command, commandType: CockpitCommandType.back);
    final didHandle = await backNavigationHandler();
    if (!didHandle) {
      return _failureExecution(
        command: command,
        durationMs: stopwatch.elapsedMilliseconds,
        snapshot: _liveSnapshot().toJson(),
        error: CockpitCommandError.assertionFailed(
          message: 'Back navigation was not handled by the current route.',
        ),
      );
    }

    await _stabilizeAfterAction(
      previousRouteName,
      commandType: CockpitCommandType.back,
    );
    return _buildSuccessWithOptionalCapture(
      command: command,
      durationMs: stopwatch.elapsedMilliseconds,
    );
  }

  Future<CockpitCommandExecution> _executeEnterText(
    CockpitCommand command,
    Stopwatch stopwatch,
  ) async {
    final previousRouteName = _liveSnapshot().routeName;
    final resolution = await _resolveWithRetry(command);
    if (!resolution.isSuccess) {
      return _failureExecution(
        command: command,
        durationMs: stopwatch.elapsedMilliseconds,
        snapshot: _liveSnapshot().toJson(),
        error: resolution.error!,
      );
    }

    final target = resolution.target!;
    final request = _textInputRequest(command);
    if (request == null ||
        !target.supportedCommands.contains(CockpitCommandType.enterText) ||
        (target.onSemanticTextInput == null &&
            target.onTextInput == null &&
            target.onSemanticEnterText == null &&
            target.onEnterText == null)) {
      return _unsupportedExecution(
        command: command,
        durationMs: stopwatch.elapsedMilliseconds,
        target: target,
      );
    }

    final semanticTextInput = target.onSemanticTextInput;
    final textInput = target.onTextInput;
    final semanticEnterText = target.onSemanticEnterText;
    final enterText = target.onEnterText;
    await _prepareForAction(command, commandType: CockpitCommandType.enterText);
    if (semanticTextInput != null) {
      semanticTextInput(request);
    } else if (textInput != null) {
      textInput(request);
    } else if (request.text != null && semanticEnterText != null) {
      semanticEnterText(request.text!);
    } else if (request.text != null && enterText != null) {
      enterText.call(request.text!);
    } else {
      return _unsupportedExecution(
        command: command,
        durationMs: stopwatch.elapsedMilliseconds,
        target: target,
      );
    }
    await _stabilizeAfterAction(previousRouteName);

    return _buildSuccessWithOptionalCapture(
      command: command,
      resolution: resolution,
      durationMs: stopwatch.elapsedMilliseconds,
    );
  }

  Future<CockpitCommandExecution> _executeFocusTextInput(
    CockpitCommand command,
    Stopwatch stopwatch,
  ) {
    return _executeStructuredTextInput(
      command: command,
      stopwatch: stopwatch,
      requiredCommand: CockpitCommandType.focusTextInput,
      requestBuilder: () => const CockpitTextInputRequest(requestFocus: true),
    );
  }

  Future<CockpitCommandExecution> _executeSetTextEditingValue(
    CockpitCommand command,
    Stopwatch stopwatch,
  ) {
    return _executeStructuredTextInput(
      command: command,
      stopwatch: stopwatch,
      requiredCommand: CockpitCommandType.setTextEditingValue,
      requestBuilder: () {
        final request = _textInputRequest(command);
        if (request == null || !request.hasEditingMutation) {
          return null;
        }
        return request;
      },
    );
  }

  Future<CockpitCommandExecution> _executeSendTextInputAction(
    CockpitCommand command,
    Stopwatch stopwatch,
  ) {
    return _executeStructuredTextInput(
      command: command,
      stopwatch: stopwatch,
      requiredCommand: CockpitCommandType.sendTextInputAction,
      requestBuilder: () {
        final request = _textInputRequest(command);
        if (request?.inputAction == null) {
          return null;
        }
        return request;
      },
    );
  }

  Future<CockpitCommandExecution> _executeStructuredTextInput({
    required CockpitCommand command,
    required Stopwatch stopwatch,
    required CockpitCommandType requiredCommand,
    required CockpitTextInputRequest? Function() requestBuilder,
  }) async {
    final request = requestBuilder();
    if (request == null) {
      final message = switch (requiredCommand) {
        CockpitCommandType.focusTextInput =>
          'focusTextInput does not require additional parameters.',
        CockpitCommandType.setTextEditingValue =>
          'setTextEditingValue requires text and/or selection parameters.',
        CockpitCommandType.sendTextInputAction =>
          'sendTextInputAction requires an inputAction parameter.',
        _ => 'Invalid text input request.',
      };
      return _failureExecution(
        command: command,
        durationMs: stopwatch.elapsedMilliseconds,
        error: CockpitCommandError.assertionFailed(message: message),
      );
    }

    final previousRouteName = _liveSnapshot().routeName;
    final resolution = await _resolveWithRetry(command);
    if (!resolution.isSuccess) {
      return _failureExecution(
        command: command,
        durationMs: stopwatch.elapsedMilliseconds,
        snapshot: _liveSnapshot().toJson(),
        error: resolution.error!,
      );
    }

    final target = resolution.target!;
    if (!target.supportedCommands.contains(requiredCommand) ||
        target.onTextInput == null) {
      return _unsupportedExecution(
        command: command,
        durationMs: stopwatch.elapsedMilliseconds,
        target: target,
      );
    }

    await _prepareForAction(command, commandType: requiredCommand);
    target.onTextInput!.call(request);
    await _stabilizeAfterAction(
      previousRouteName,
      commandType: requiredCommand,
    );
    return _buildSuccessWithOptionalCapture(
      command: command,
      resolution: resolution,
      durationMs: stopwatch.elapsedMilliseconds,
    );
  }

  Future<CockpitCommandExecution> _executeKeyEvent(
    CockpitCommand command,
    Stopwatch stopwatch,
  ) async {
    final request = _keyEventRequest(command);
    if (request == null) {
      return _failureExecution(
        command: command,
        durationMs: stopwatch.elapsedMilliseconds,
        error: CockpitCommandError.assertionFailed(
          message:
              '${command.commandType.name} requires a logicalKey parameter.',
        ),
      );
    }
    await _prepareForAction(command, commandType: command.commandType);
    final handled = await _keyEventHandler(request, command.commandType);
    await _settleBeforeObservation();
    return _successExecution(
      command: command,
      durationMs: stopwatch.elapsedMilliseconds,
      snapshot: _appendWarningsToSnapshot(_liveSnapshot().toJson(), [
        if (!handled)
          <String, Object?>{
            'code': 'unhandledKeyEvent',
            'message':
                'The keyboard event was dispatched but no focused handler reported it as handled.',
            'details': request.toJson(),
          },
      ]),
    );
  }

  Future<CockpitCommandExecution> _executeSemanticAction(
    CockpitCommand command,
    Stopwatch stopwatch, {
    required CockpitCommandType requiredCommand,
    required CockpitSemanticActionHandler? Function(CockpitTarget target)
        semanticAction,
  }) async {
    final previousRouteName = _liveSnapshot().routeName;
    final resolution = await _resolveWithRetry(command);
    if (!resolution.isSuccess) {
      return _failureExecution(
        command: command,
        durationMs: stopwatch.elapsedMilliseconds,
        snapshot: _liveSnapshot().toJson(),
        error: resolution.error!,
      );
    }

    final target = resolution.target!;
    final action = semanticAction(target);
    if (!target.supportedCommands.contains(requiredCommand) || action == null) {
      return _unsupportedExecution(
        command: command,
        durationMs: stopwatch.elapsedMilliseconds,
        target: target,
      );
    }

    await _prepareForAction(command, commandType: requiredCommand);
    action.call();
    await _stabilizeAfterAction(
      previousRouteName,
      commandType: requiredCommand,
    );
    return _buildSuccessWithOptionalCapture(
      command: command,
      resolution: resolution,
      durationMs: stopwatch.elapsedMilliseconds,
    );
  }

  Future<CockpitCommandExecution> _executeAssertVisible(
    CockpitCommand command,
    Stopwatch stopwatch,
  ) async {
    final resolution = await _resolveWithRetry(command);
    if (!resolution.isSuccess) {
      return _failureExecution(
        command: command,
        durationMs: stopwatch.elapsedMilliseconds,
        snapshot: _liveSnapshot().toJson(),
        error: resolution.error!,
      );
    }

    return _successExecution(
      command: command,
      durationMs: stopwatch.elapsedMilliseconds,
      locatorResolution: resolution.locatorResolution,
      snapshot: _liveSnapshot().toJson(),
    );
  }

  Future<CockpitCommandExecution> _executeAssertText(
    CockpitCommand command,
    Stopwatch stopwatch,
  ) async {
    final expectedText = _expectedText(command);
    if (expectedText == null || expectedText.isEmpty) {
      return _failureExecution(
        command: command,
        durationMs: stopwatch.elapsedMilliseconds,
        error: CockpitCommandError.assertionFailed(
          message: 'assertText requires a non-empty expected text value.',
        ),
      );
    }

    final snapshot = _liveSnapshot();
    if (_visibleTargetsContainText(_registry.visibleTargets, expectedText)) {
      return _successExecution(
        command: command,
        durationMs: stopwatch.elapsedMilliseconds,
        snapshot: snapshot.toJson(),
      );
    }

    return _failureExecution(
      command: command,
      durationMs: stopwatch.elapsedMilliseconds,
      snapshot: snapshot.toJson(),
      error: CockpitCommandError.assertionFailed(
        message: 'Expected visible text "$expectedText" was not found.',
        details: <String, Object?>{
          'expectedText': expectedText,
          'visibleTextCandidates': _visibleTextCandidates(
            _registry.visibleTargets,
          ),
        },
      ),
    );
  }

  Future<CockpitCommandExecution> _executeWaitFor(
    CockpitCommand command,
    Stopwatch stopwatch,
  ) async {
    final timeoutMs = command.timeoutMs ?? 2000;
    final waitCondition = _describeWaitCondition(command);
    if (waitCondition == null) {
      return _failureExecution(
        command: command,
        durationMs: stopwatch.elapsedMilliseconds,
        error: CockpitCommandError.timeout(
          message:
              'waitFor requires a locator, routeName parameter, or text parameter.',
        ),
      );
    }

    while (stopwatch.elapsedMilliseconds <= timeoutMs) {
      final snapshot = _liveSnapshot();
      final routeName = _expectedRouteName(command);
      if (routeName != null && snapshot.routeName == routeName) {
        return _successExecution(
          command: command,
          durationMs: stopwatch.elapsedMilliseconds,
          locatorResolution: CockpitLocatorResolution(
            matchedKind: CockpitLocatorKind.route,
            matchedValue: routeName,
          ),
          snapshot: snapshot.toJson(),
        );
      }

      final expectedText = _expectedText(command);
      if (expectedText != null &&
          _visibleTargetsContainText(_registry.visibleTargets, expectedText)) {
        return _successExecution(
          command: command,
          durationMs: stopwatch.elapsedMilliseconds,
          locatorResolution: CockpitLocatorResolution(
            matchedKind: CockpitLocatorKind.text,
            matchedValue: expectedText,
          ),
          snapshot: snapshot.toJson(),
        );
      }

      final locator = command.locator;
      if (locator != null &&
          locator.kind != CockpitLocatorKind.route &&
          locator.kind != CockpitLocatorKind.text) {
        final resolution = _resolve(command);
        if (resolution.isSuccess) {
          return _successExecution(
            command: command,
            durationMs: stopwatch.elapsedMilliseconds,
            locatorResolution: resolution.locatorResolution,
            snapshot: snapshot.toJson(),
          );
        }
        if (resolution.error?.code == CockpitCommandError.ambiguousTargetCode) {
          return _failureExecution(
            command: command,
            durationMs: stopwatch.elapsedMilliseconds,
            snapshot: snapshot.toJson(),
            error: resolution.error!,
          );
        }
      }

      await _postActionSettler();
      await _waitTickHandler(const Duration(milliseconds: 16));
    }

    return _failureExecution(
      command: command,
      durationMs: stopwatch.elapsedMilliseconds,
      snapshot: _liveSnapshot().toJson(),
      error: CockpitCommandError.timeout(
        message: 'Timed out waiting for $waitCondition.',
        details: <String, Object?>{
          'waitCondition': waitCondition,
          'timeoutMs': timeoutMs,
        },
      ),
    );
  }

  Future<CockpitCommandExecution> _executeCaptureScreenshot(
    CockpitCommand command,
    Stopwatch stopwatch,
  ) async {
    final capture = await _captureOrchestrator.captureExplicit(
      command,
      waitForNetworkIdleDuringAcceptanceCapture:
          _interactionPolicy.waitForNetworkIdleDuringAcceptanceCapture,
    );
    if (capture == null) {
      return _failureExecution(
        command: command,
        durationMs: stopwatch.elapsedMilliseconds,
        error: CockpitCommandError.unsupportedCapability(
          message: 'Flutter view capture is not available for this executor.',
        ),
      );
    }
    return _successExecution(
      command: command,
      durationMs: stopwatch.elapsedMilliseconds,
      artifacts: capture.artifacts,
      snapshot: capture.snapshot,
      requestedCaptureProfile: capture.requestedCaptureProfile,
      resolvedCaptureKind: capture.resolvedCaptureKind,
      usedCaptureFallback: capture.usedCaptureFallback,
      degradationReason: capture.degradationReason,
      artifactPayloads: capture.artifactPayloads,
    );
  }

  CockpitGestureAction _buildDirectionalGesture({
    required CockpitCommand command,
    required CockpitTarget? target,
    required Offset delta,
    required Duration duration,
    required CockpitCommandType fallbackType,
    Duration holdDuration = Duration.zero,
    double touchSlopX = cockpitDefaultDragTouchSlop,
    double touchSlopY = cockpitDefaultDragTouchSlop,
    int moveEventCount = 0,
  }) {
    final pointerDeviceKind = _pointerDeviceKindParameter(
      command,
      allowTrackpad: true,
    );
    final profile = _gestureProfileParameter(command);
    final sampleHz = _doubleParameter(command, 'sampleHz');
    final frameInterval = _optionalDurationParameter(
      command,
      'frameIntervalMs',
    );
    final initialHoldDuration = _optionalDurationParameter(
      command,
      'initialHoldMs',
    );
    if (pointerDeviceKind == PointerDeviceKind.trackpad) {
      return CockpitGestureAction.panZoom(
        target: target,
        origin: _startPointParameter(command),
        anchor: _gestureAnchorParameter(command),
        delta: delta,
        duration: duration,
        moveEventCount: moveEventCount,
        profile: profile,
        sampleHz: sampleHz,
        frameInterval: frameInterval,
        initialHoldDuration: initialHoldDuration,
      );
    }

    return switch (fallbackType) {
      CockpitCommandType.drag => CockpitGestureAction.drag(
          target: target,
          origin: _startPointParameter(command),
          anchor: _gestureAnchorParameter(command),
          delta: delta,
          duration: duration,
          holdDuration: holdDuration,
          touchSlopX: touchSlopX,
          touchSlopY: touchSlopY,
          moveEventCount: moveEventCount,
          profile: profile,
          sampleHz: sampleHz,
          frameInterval: frameInterval,
          initialHoldDuration: initialHoldDuration,
          pointerDeviceKind: pointerDeviceKind,
          buttons: _buttonsParameter(command),
        ),
      CockpitCommandType.fling => CockpitGestureAction.fling(
          target: target,
          origin: _startPointParameter(command),
          anchor: _gestureAnchorParameter(command),
          delta: delta,
          duration: duration,
          moveEventCount: moveEventCount,
          profile: profile,
          sampleHz: sampleHz,
          frameInterval: frameInterval,
          initialHoldDuration: initialHoldDuration,
          pointerDeviceKind: pointerDeviceKind,
          buttons: _buttonsParameter(command),
        ),
      _ => throw ArgumentError(
          'Directional gestures only support drag and fling fallbacks.',
        ),
    };
  }

  CockpitGestureAction _buildSwipeGesture({
    required CockpitCommand command,
    required CockpitTarget? target,
    required AxisDirection direction,
    required double distanceFactor,
    required Duration duration,
    required int moveEventCount,
  }) {
    final pointerDeviceKind = _pointerDeviceKindParameter(
      command,
      allowTrackpad: true,
    );
    final profile = _gestureProfileParameter(command);
    final sampleHz = _doubleParameter(command, 'sampleHz');
    final frameInterval = _optionalDurationParameter(
      command,
      'frameIntervalMs',
    );
    final initialHoldDuration = _optionalDurationParameter(
      command,
      'initialHoldMs',
    );
    if (pointerDeviceKind == PointerDeviceKind.trackpad) {
      final geometry = target == null
          ? null
          : CockpitTargetGeometryResolver.maybeFromTarget(target);
      final distance = switch (direction) {
        AxisDirection.left ||
        AxisDirection.right =>
          ((geometry?.width ?? 240) * distanceFactor).clamp(24, 640),
        AxisDirection.up ||
        AxisDirection.down =>
          ((geometry?.height ?? 240) * distanceFactor).clamp(24, 640),
      }
          .toDouble();
      final delta = switch (direction) {
        AxisDirection.left => Offset(-distance, 0),
        AxisDirection.right => Offset(distance, 0),
        AxisDirection.up => Offset(0, -distance),
        AxisDirection.down => Offset(0, distance),
      };
      return CockpitGestureAction.panZoom(
        target: target,
        origin: _startPointParameter(command),
        anchor: _gestureAnchorParameter(command),
        delta: delta,
        duration: duration,
        moveEventCount: moveEventCount,
        profile: profile,
        sampleHz: sampleHz,
        frameInterval: frameInterval,
        initialHoldDuration: initialHoldDuration,
      );
    }

    return CockpitGestureAction.swipe(
      target: target,
      origin: _startPointParameter(command),
      anchor: _gestureAnchorParameter(command),
      direction: direction,
      distanceFactor: distanceFactor,
      duration: duration,
      moveEventCount: moveEventCount,
      profile: profile,
      sampleHz: sampleHz,
      frameInterval: frameInterval,
      initialHoldDuration: initialHoldDuration,
      pointerDeviceKind: pointerDeviceKind,
      buttons: _buttonsParameter(command),
    );
  }

  CockpitGestureAction _buildPinchZoomGesture({
    required CockpitCommand command,
    required CockpitTarget? target,
    required double scale,
    required double startSpan,
    required Duration duration,
    required int moveEventCount,
  }) {
    final profile = _gestureProfileParameter(
      command,
      fallback: CockpitGestureProfile.precise,
    );
    final sampleHz = _doubleParameter(command, 'sampleHz');
    final frameInterval = _optionalDurationParameter(
      command,
      'frameIntervalMs',
    );
    final initialHoldDuration = _optionalDurationParameter(
      command,
      'initialHoldMs',
    );
    final pointerDeviceKind = _pointerDeviceKindParameter(
      command,
      allowTrackpad: true,
    );
    if (pointerDeviceKind == PointerDeviceKind.trackpad) {
      return CockpitGestureAction.panZoom(
        target: target,
        origin: _pointParameter(command),
        anchor: _gestureAnchorParameter(command),
        scale: scale,
        duration: duration,
        moveEventCount: moveEventCount,
        profile: profile,
        sampleHz: sampleHz,
        frameInterval: frameInterval,
        initialHoldDuration: initialHoldDuration,
      );
    }
    return CockpitGestureAction.pinchZoom(
      target: target,
      origin: _pointParameter(command),
      anchor: _gestureAnchorParameter(command),
      scale: scale,
      startSpan: startSpan,
      duration: duration,
      moveEventCount: moveEventCount,
      profile: profile,
      sampleHz: sampleHz,
      frameInterval: frameInterval,
      initialHoldDuration: initialHoldDuration,
    );
  }

  CockpitGestureAction _buildRotateGesture({
    required CockpitCommand command,
    required CockpitTarget? target,
    required double rotation,
    required double startSpan,
    required Duration duration,
    required int moveEventCount,
  }) {
    final profile = _gestureProfileParameter(
      command,
      fallback: CockpitGestureProfile.precise,
    );
    final sampleHz = _doubleParameter(command, 'sampleHz');
    final frameInterval = _optionalDurationParameter(
      command,
      'frameIntervalMs',
    );
    final initialHoldDuration = _optionalDurationParameter(
      command,
      'initialHoldMs',
    );
    final pointerDeviceKind = _pointerDeviceKindParameter(
      command,
      allowTrackpad: true,
    );
    if (pointerDeviceKind == PointerDeviceKind.trackpad) {
      return CockpitGestureAction.panZoom(
        target: target,
        origin: _pointParameter(command),
        anchor: _gestureAnchorParameter(command),
        rotation: rotation,
        duration: duration,
        moveEventCount: moveEventCount,
        profile: profile,
        sampleHz: sampleHz,
        frameInterval: frameInterval,
        initialHoldDuration: initialHoldDuration,
      );
    }
    return CockpitGestureAction.rotate(
      target: target,
      origin: _pointParameter(command),
      anchor: _gestureAnchorParameter(command),
      rotation: rotation,
      startSpan: startSpan,
      duration: duration,
      moveEventCount: moveEventCount,
      profile: profile,
      sampleHz: sampleHz,
      frameInterval: frameInterval,
      initialHoldDuration: initialHoldDuration,
    );
  }

  Future<CockpitCommandExecution> _executeOptionalTargetGesture({
    required CockpitCommand command,
    required Stopwatch stopwatch,
    required CockpitGestureAction Function(CockpitTarget? target) actionBuilder,
  }) async {
    final locator = command.locator;
    if (locator == null) {
      return _executeResolvedGesture(
        command: command,
        stopwatch: stopwatch,
        resolution: null,
        actionBuilder: () => actionBuilder(null),
      );
    }

    final resolution = await _resolveWithRetry(command);
    if (!resolution.isSuccess) {
      return _failureExecution(
        command: command,
        durationMs: stopwatch.elapsedMilliseconds,
        snapshot: _liveSnapshot().toJson(),
        error: resolution.error!,
      );
    }

    return _executeResolvedGesture(
      command: command,
      stopwatch: stopwatch,
      resolution: resolution,
      actionBuilder: () => actionBuilder(resolution.target),
    );
  }

  Future<CockpitCommandExecution> _executeResolvedGesture({
    required CockpitCommand command,
    required Stopwatch stopwatch,
    required CockpitGestureAction Function() actionBuilder,
    CockpitTargetResolutionResult? resolution,
  }) async {
    final previousRouteName = _liveSnapshot().routeName;
    await _prepareForAction(command, commandType: command.commandType);
    CockpitGestureAction action;
    try {
      action = actionBuilder();
    } on ArgumentError catch (error) {
      return _failureExecution(
        command: command,
        durationMs: stopwatch.elapsedMilliseconds,
        locatorResolution: resolution?.locatorResolution,
        error: CockpitCommandError.invalidGestureParameters(
          message: error.message?.toString() ?? 'Invalid gesture parameters.',
        ),
      );
    }
    final result = await _executeGestureAction(
      command: command,
      stopwatch: stopwatch,
      resolution: resolution,
      action: action,
      previousRouteName: previousRouteName,
    );
    if (result != null) {
      return result;
    }
    return _failureExecution(
      command: command,
      durationMs: stopwatch.elapsedMilliseconds,
      error: CockpitCommandError.unsupportedCapability(
        message: 'Gesture handling is not available for this executor.',
      ),
    );
  }

  Future<CockpitCommandExecution?> _executeGestureAction({
    required CockpitCommand command,
    required Stopwatch stopwatch,
    required CockpitGestureAction action,
    required String? previousRouteName,
    CockpitTargetResolutionResult? resolution,
  }) async {
    final gestureHandler = _gestureHandler;
    if (gestureHandler == null) {
      return null;
    }

    final preflight = _preflightGestureHitTest(
      command: command,
      action: action,
      target: resolution?.target,
    );
    if (preflight?.error != null) {
      return _failureExecution(
        command: command,
        durationMs: stopwatch.elapsedMilliseconds,
        locatorResolution: resolution?.locatorResolution,
        snapshot: _liveSnapshot().toJson(),
        error: preflight!.error!,
      );
    }

    try {
      await gestureHandler(action);
    } on ArgumentError catch (error) {
      return _failureExecution(
        command: command,
        durationMs: stopwatch.elapsedMilliseconds,
        locatorResolution: resolution?.locatorResolution,
        error: CockpitCommandError.invalidGestureParameters(
          message: error.message?.toString() ?? 'Invalid gesture parameters.',
          details: <String, Object?>{'gestureType': command.commandType.name},
        ),
      );
    } on StateError catch (error) {
      return _failureExecution(
        command: command,
        durationMs: stopwatch.elapsedMilliseconds,
        locatorResolution: resolution?.locatorResolution,
        error: CockpitCommandError.gestureExecutionFailed(
          message: error.message,
          details: <String, Object?>{
            'gestureType': command.commandType.name,
            if (command.locator != null) 'locator': command.locator!.toJson(),
          },
        ),
      );
    } on Object catch (error) {
      return _failureExecution(
        command: command,
        durationMs: stopwatch.elapsedMilliseconds,
        locatorResolution: resolution?.locatorResolution,
        error: CockpitCommandError.gestureExecutionFailed(
          message: 'Gesture execution failed unexpectedly.',
          details: <String, Object?>{
            'gestureType': command.commandType.name,
            'error': error.toString(),
          },
        ),
      );
    }
    await _stabilizeAfterAction(
      previousRouteName,
      commandType: command.commandType,
    );
    return _buildSuccessWithOptionalCapture(
      command: command,
      resolution: resolution,
      durationMs: stopwatch.elapsedMilliseconds,
      degradationReason: preflight?.degradationReason,
      warnings: preflight?.warning == null
          ? const []
          : <Map<String, Object?>>[preflight!.warning!],
    );
  }

  _CockpitGesturePreflightResult? _preflightGestureHitTest({
    required CockpitCommand command,
    required CockpitGestureAction action,
    required CockpitTarget? target,
  }) {
    if (target == null) {
      return null;
    }
    final policy = _hitTestMissPolicy(command);
    if (policy == CockpitHitTestMissPolicy.ignore) {
      return null;
    }
    final probePosition = _gestureProbePosition(action, target);
    final result = CockpitTargetHitTestInspector.inspect(
      target,
      position: probePosition,
    );
    if (result == null || result.hit) {
      return null;
    }
    final details = <String, Object?>{
      'gestureType': command.commandType.name,
      'target': target.registrationId,
      if (target.displayLabel != null) 'targetLabel': target.displayLabel,
      'routeName': target.routeName,
      'hitTest': result.toJson(),
      'hitTestMissPolicy': policy.name,
    };
    if (policy == CockpitHitTestMissPolicy.fail) {
      return _CockpitGesturePreflightResult.error(
        CockpitCommandError.targetNotHittable(
          message:
              'The resolved target is visible in discovery data but is not hittable at the gesture position.',
          details: details,
        ),
      );
    }
    return _CockpitGesturePreflightResult.warning(<String, Object?>{
      'code': 'hitTestMiss',
      'message':
          'The gesture target did not win hit testing at the resolved position; execution continued because hitTestMissPolicy=warn.',
      'details': details,
    });
  }

  Offset? _gestureProbePosition(
    CockpitGestureAction action,
    CockpitTarget? target,
  ) {
    if (action.origin != null) {
      return action.origin;
    }
    final geometry = action.geometry ??
        (target == null
            ? null
            : CockpitTargetGeometryResolver.maybeFromTarget(target));
    if (geometry == null) {
      return null;
    }
    final anchor = action.anchor == CockpitGestureAnchor.textHitTestable
        ? CockpitGestureAnchor.center
        : action.anchor;
    final resolved = geometry.resolveAnchorPosition(anchor);
    return Offset(resolved.dx, resolved.dy);
  }

  CockpitTargetResolutionResult _resolve(CockpitCommand command) {
    final locator = command.locator;
    if (locator == null) {
      return CockpitTargetResolutionResult.failure(
        error: CockpitCommandError.targetNotFound(
          message: 'Command requires a locator but none was provided.',
        ),
      );
    }
    return _registry.resolve(locator);
  }

  Future<CockpitTargetResolutionResult> _resolveWithRetry(
    CockpitCommand command, {
    int attempts = 3,
  }) async {
    var resolution = _resolve(command);
    if (_shouldStopResolutionRetry(resolution) || attempts <= 1) {
      return _enrichResolutionFailure(command, resolution);
    }

    final resolveTimeout = _durationFromOptionalPositiveInt(
      command,
      key: 'preActionTimeoutMs',
      fallback: _interactionPolicy.targetResolveTimeout,
    );
    final resolvePollInterval = _durationFromOptionalPositiveInt(
      command,
      key: 'preActionPollIntervalMs',
      fallback: _interactionPolicy.targetResolvePollInterval,
    );
    final stopwatch = Stopwatch()..start();
    var retryCount = 0;
    while (retryCount < attempts - 1 || stopwatch.elapsed < resolveTimeout) {
      await _postActionSettler();
      if (_usesTestBinding() && !_hasCustomWaitTickHandler) {
        await Future<void>.microtask(() {});
      } else {
        await _waitTickHandler(resolvePollInterval);
      }
      await _settleBeforeObservation();
      resolution = _resolve(command);
      if (_shouldStopResolutionRetry(resolution)) {
        return _enrichResolutionFailure(command, resolution);
      }
      retryCount += 1;
    }
    return _enrichResolutionFailure(command, resolution);
  }

  bool _shouldStopResolutionRetry(CockpitTargetResolutionResult resolution) {
    return resolution.isSuccess ||
        resolution.error?.code != CockpitCommandError.targetNotFoundCode;
  }

  CockpitTargetResolutionResult _enrichResolutionFailure(
    CockpitCommand command,
    CockpitTargetResolutionResult resolution,
  ) {
    final error = resolution.error;
    if (error == null ||
        error.code != CockpitCommandError.targetNotFoundCode ||
        command.locator == null) {
      return resolution;
    }
    return CockpitTargetResolutionResult.failure(
      error: CockpitCommandError.targetNotFound(
        message: error.message,
        details: <String, Object?>{
          ...error.details,
          'routeName': _liveSnapshot().routeName,
          'visibleTargetCount': _registry.visibleTargets.length,
          'visibleTargetSignals': _visibleTargetSignals(),
        },
      ),
      matches: resolution.matches,
    );
  }

  List<Map<String, Object?>> _visibleTargetSignals() {
    return _registry.visibleTargets.take(24).map((target) {
      return <String, Object?>{
        'registrationId': target.registrationId,
        'typeName': target.typeName,
        'routeName': target.routeName,
        if (target.keyValue != null) 'key': target.keyValue,
        if (target.semanticId != null) 'semanticId': target.semanticId,
        if (target.text != null) 'text': target.text,
        if (target.tooltip != null) 'tooltip': target.tooltip,
        'supportedCommands': target.supportedCommands
            .map((command) => command.name)
            .toList(growable: false),
      };
    }).toList(growable: false);
  }

  Future<CockpitCommandExecution> _buildSuccessWithOptionalCapture({
    required CockpitCommand command,
    CockpitTargetResolutionResult? resolution,
    required int durationMs,
    String? degradationReason,
    List<Map<String, Object?>> warnings = const <Map<String, Object?>>[],
  }) async {
    final snapshot = _appendWarningsToSnapshot(
      _liveSnapshot().toJson(),
      warnings,
    );
    final capture = await _captureOrchestrator.captureAfterAction(command);
    if (capture == null) {
      return _successExecution(
        command: command,
        durationMs: durationMs,
        locatorResolution: resolution?.locatorResolution,
        snapshot: snapshot,
        degradationReason: degradationReason,
      );
    }

    return _successExecution(
      command: command,
      durationMs: durationMs,
      locatorResolution: resolution?.locatorResolution,
      artifacts: capture.artifacts,
      snapshot: _appendWarningsToSnapshot(
        capture.snapshot ?? snapshot,
        warnings,
      ),
      requestedCaptureProfile: capture.requestedCaptureProfile,
      resolvedCaptureKind: capture.resolvedCaptureKind,
      usedCaptureFallback: capture.usedCaptureFallback,
      degradationReason: degradationReason ?? capture.degradationReason,
      artifactPayloads: capture.artifactPayloads,
    );
  }

  CockpitCommandExecution _successExecution({
    required CockpitCommand command,
    required int durationMs,
    CockpitLocatorResolution? locatorResolution,
    List<CockpitArtifactRef> artifacts = const <CockpitArtifactRef>[],
    Map<String, Object?>? snapshot,
    CockpitCaptureProfile? requestedCaptureProfile,
    CockpitCaptureKind? resolvedCaptureKind,
    bool usedCaptureFallback = false,
    String? degradationReason,
    Map<String, List<int>> artifactPayloads = const <String, List<int>>{},
  }) {
    return CockpitCommandExecution(
      result: CockpitCommandResult(
        success: true,
        commandId: command.commandId,
        commandType: command.commandType,
        locatorResolution: locatorResolution,
        durationMs: durationMs,
        artifacts: artifacts,
        snapshot: snapshot,
        requestedCaptureProfile: requestedCaptureProfile,
        resolvedCaptureKind: resolvedCaptureKind,
        usedCaptureFallback: usedCaptureFallback,
        degradationReason: degradationReason,
      ),
      artifactPayloads: artifactPayloads,
    );
  }

  CockpitCommandExecution _failureExecution({
    required CockpitCommand command,
    required int durationMs,
    required CockpitCommandError error,
    CockpitLocatorResolution? locatorResolution,
    List<CockpitArtifactRef> artifacts = const <CockpitArtifactRef>[],
    Map<String, Object?>? snapshot,
  }) {
    return CockpitCommandExecution(
      result: CockpitCommandResult(
        success: false,
        commandId: command.commandId,
        commandType: command.commandType,
        locatorResolution: locatorResolution,
        durationMs: durationMs,
        artifacts: artifacts,
        snapshot: snapshot,
        error: error,
      ),
    );
  }

  CockpitCommandExecution _unsupportedExecution({
    required CockpitCommand command,
    required int durationMs,
    required CockpitTarget target,
  }) {
    return _failureExecution(
      command: command,
      durationMs: durationMs,
      error: CockpitCommandError.unsupportedCapability(
        message:
            '${command.commandType.name} is not supported by target ${target.registrationId}.',
        details: <String, Object?>{
          'target': target.registrationId,
          'commandType': command.commandType.name,
        },
      ),
    );
  }

  static Future<void> _defaultPostActionSettler() async {
    SchedulerBinding schedulerBinding;
    WidgetsBinding widgetsBinding;
    try {
      schedulerBinding = SchedulerBinding.instance;
      widgetsBinding = WidgetsBinding.instance;
    } on Object {
      return;
    }
    if (_isTestBinding(widgetsBinding)) {
      return;
    }
    await Future<void>.microtask(() {});
    if (schedulerBinding.schedulerPhase != SchedulerPhase.idle) {
      await widgetsBinding.endOfFrame;
      await Future<void>.microtask(() {});
    }
  }

  static Future<void> _defaultWaitTickHandler(Duration duration) {
    return Future<void>.delayed(duration);
  }

  static Future<bool> _defaultKeyEventHandler(
    CockpitKeyEventRequest request,
    CockpitCommandType type,
  ) async {
    // `flutter_test` still drives synthetic key delivery through KeyEventManager.
    // The newer HardwareKeyboard handler API is observer-oriented and does not
    // provide an imperative dispatch surface for app-side automation.
    bool dispatchKeyData(ui.KeyData keyData) =>
        ServicesBinding.instance.keyEventManager.handleKeyData(keyData);

    final physicalKey = request.physicalKey;
    final keyData = switch (type) {
      CockpitCommandType.sendKeyEvent ||
      CockpitCommandType.sendKeyDownEvent =>
        ui.KeyData(
          type: ui.KeyEventType.down,
          physical: physicalKey?.usbHidUsage ?? 0,
          logical: request.logicalKey.keyId,
          timeStamp: Duration.zero,
          character:
              request.character ?? _fallbackCharacterFor(request.logicalKey),
          synthesized: false,
        ),
      CockpitCommandType.sendKeyUpEvent => ui.KeyData(
          type: ui.KeyEventType.up,
          physical: physicalKey?.usbHidUsage ?? 0,
          logical: request.logicalKey.keyId,
          timeStamp: Duration.zero,
          character: null,
          synthesized: false,
        ),
      _ => throw ArgumentError.value(
          type,
          'type',
          'Unsupported key event type.',
        ),
    };
    final handled = dispatchKeyData(keyData);
    if (type != CockpitCommandType.sendKeyEvent) {
      return handled;
    }
    final releaseHandled = dispatchKeyData(
      ui.KeyData(
        type: ui.KeyEventType.up,
        physical: physicalKey?.usbHidUsage ?? 0,
        logical: request.logicalKey.keyId,
        timeStamp: Duration.zero,
        character: null,
        synthesized: false,
      ),
    );
    return handled || releaseHandled;
  }

  static String? _fallbackCharacterFor(LogicalKeyboardKey logicalKey) {
    final label = logicalKey.keyLabel;
    return label.isEmpty ? null : label;
  }

  Future<void> _stabilizeAfterAction(
    String? previousRouteName, {
    CockpitCommandType? commandType,
  }) async {
    await _postActionSettler();
    await _waitForGestureCommit(commandType);
    final routeChanged = await _waitForRouteTargets(previousRouteName);
    await _settleBeforeObservation();
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
      CockpitCommandType.tap ||
      CockpitCommandType.doubleTap =>
        kDoubleTapTimeout + const Duration(milliseconds: 32),
      _ => Duration.zero,
    };
    if (commitDelay > Duration.zero) {
      await Future<void>.delayed(commitDelay);
    }
  }

  String? _expectedText(CockpitCommand command) {
    final value = command.parameters['text'];
    if (value is String && value.isNotEmpty) {
      return value;
    }
    final locator = command.locator;
    if (locator != null && locator.kind == CockpitLocatorKind.text) {
      return locator.value;
    }
    return null;
  }

  Future<void> _prepareForAction(
    CockpitCommand command, {
    required CockpitCommandType commandType,
  }) async {
    await _postActionSettler();
    await _settleBeforeObservation();
    await _waitForPreActionContinuity(command, commandType: commandType);
  }

  CockpitLocatorResolution? _scrollLocatorResolution(CockpitCommand command) {
    final locator = command.locator;
    if (locator == null) {
      return null;
    }

    final snapshot = _liveSnapshot();
    if (locator.kind == CockpitLocatorKind.text &&
        _visibleTargetsContainMeaningfullyVisibleText(
          _registry.visibleTargets,
          locator.value,
        )) {
      return CockpitLocatorResolution(
        matchedKind: CockpitLocatorKind.text,
        matchedValue: locator.value,
      );
    }
    if (locator.kind == CockpitLocatorKind.route &&
        snapshot.routeName == locator.value) {
      return CockpitLocatorResolution(
        matchedKind: CockpitLocatorKind.route,
        matchedValue: locator.value,
      );
    }
    return null;
  }

  bool _allowsGenericScrollResolution(CockpitLocator locator) {
    return switch (locator.kind) {
      CockpitLocatorKind.text || CockpitLocatorKind.route => false,
      _ => true,
    };
  }

  bool _visibleTargetsContainMeaningfullyVisibleText(
    Iterable<CockpitTarget> visibleTargets,
    String expectedText,
  ) {
    final matches = visibleTargets
        .where((target) => _targetContainsText(target, expectedText))
        .toList(growable: false);
    if (matches.isEmpty) {
      return false;
    }

    return matches.any(_isMeaningfullyVisibleTextTarget);
  }

  bool _isMeaningfullyVisibleTextTarget(CockpitTarget target) {
    final hitTest = CockpitTargetHitTestInspector.inspect(target);
    if (hitTest == null) {
      return true;
    }
    return hitTest.withinTargetBounds && hitTest.hit;
  }

  String? _expectedRouteName(CockpitCommand command) {
    final value =
        command.parameters['routeName'] ?? command.parameters['route'];
    if (value is String && value.isNotEmpty) {
      return value;
    }
    final locator = command.locator;
    if (locator != null && locator.kind == CockpitLocatorKind.route) {
      return locator.value;
    }
    return null;
  }

  Duration _durationParameter(
    CockpitCommand command, {
    required String key,
    required int fallbackMs,
  }) {
    final value = _intParameter(command, key);
    if (value == null) {
      return Duration(milliseconds: fallbackMs);
    }
    if (value <= 0) {
      throw ArgumentError('$key must be positive.');
    }
    return Duration(milliseconds: value);
  }

  Duration _optionalDurationParameter(CockpitCommand command, String key) {
    final value = _intParameter(command, key);
    if (value == null) {
      return Duration.zero;
    }
    if (value <= 0) {
      throw ArgumentError('$key must be positive.');
    }
    return Duration(milliseconds: value);
  }

  Duration _durationFromOptionalPositiveInt(
    CockpitCommand command, {
    required String key,
    required Duration fallback,
  }) {
    final value = _intParameter(command, key);
    if (value == null) {
      return fallback;
    }
    if (value <= 0) {
      throw ArgumentError('$key must be positive.');
    }
    return Duration(milliseconds: value);
  }

  int? _intParameter(CockpitCommand command, String key) {
    final value = command.parameters[key];
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return null;
  }

  double? _doubleParameter(CockpitCommand command, String key) {
    final value = command.parameters[key];
    if (value is double) {
      return value;
    }
    if (value is num) {
      return value.toDouble();
    }
    return null;
  }

  Offset? _pointParameter(CockpitCommand command) {
    final x = _doubleParameter(command, 'x');
    final y = _doubleParameter(command, 'y');
    if (x == null || y == null) {
      return null;
    }
    return Offset(x, y);
  }

  Offset? _startPointParameter(CockpitCommand command) {
    final x =
        _doubleParameter(command, 'startX') ?? _doubleParameter(command, 'x');
    final y =
        _doubleParameter(command, 'startY') ?? _doubleParameter(command, 'y');
    if (x == null || y == null) {
      return null;
    }
    return Offset(x, y);
  }

  bool _allowMissedHit(CockpitCommand command) {
    return _boolParameter(command, 'allowMissedHit') == true ||
        _boolParameter(command, 'warnIfMissed') == false;
  }

  CockpitHitTestMissPolicy _hitTestMissPolicy(CockpitCommand command) {
    if (_allowMissedHit(command)) {
      return CockpitHitTestMissPolicy.ignore;
    }
    return CockpitHitTestMissPolicy.maybeFromJson(
          command.parameters['hitTestMissPolicy'],
        ) ??
        _interactionPolicy.hitTestMissPolicy;
  }

  CockpitTextInputRequest? _textInputRequest(CockpitCommand command) {
    final text = command.parameters['text'];
    final stringText = text is String ? text : null;
    final selectionBase = _intParameter(command, 'selectionBase');
    final selectionExtent =
        _intParameter(command, 'selectionExtent') ?? selectionBase;
    final inputAction = CockpitTextInputAction.maybeFromJson(
      command.parameters['inputAction'],
    );
    final requestFocus = _boolParameter(command, 'requestFocus') ?? true;
    final clearExisting = _boolParameter(command, 'clearExisting') ?? false;

    if (stringText == null &&
        selectionBase == null &&
        selectionExtent == null &&
        inputAction == null &&
        !requestFocus &&
        !clearExisting) {
      return null;
    }

    return CockpitTextInputRequest(
      text: stringText,
      selectionBase: selectionBase,
      selectionExtent: selectionExtent,
      inputAction: inputAction,
      requestFocus: requestFocus,
      clearExisting: clearExisting,
    );
  }

  CockpitKeyEventRequest? _keyEventRequest(CockpitCommand command) {
    if (!command.parameters.containsKey('logicalKey')) {
      return null;
    }
    return CockpitKeyEventRequest.fromJson(command.parameters);
  }

  CockpitGestureProfile _gestureProfileParameter(
    CockpitCommand command, {
    CockpitGestureProfile fallback = CockpitGestureProfile.userLike,
  }) {
    return CockpitGestureProfile.maybeFromJson(
          command.parameters['gestureProfile'],
        ) ??
        fallback;
  }

  CockpitRevealAlignment? _revealAlignmentParameter(CockpitCommand command) {
    return CockpitRevealAlignment.tryParse(
      command.parameters['revealAlignment'],
    );
  }

  CockpitGestureAnchor _gestureAnchorParameter(CockpitCommand command) {
    return CockpitGestureAnchor.maybeFromJson(
      command.parameters['anchor'] ?? command.parameters['gestureAnchor'],
    );
  }

  Map<String, Object?>? _appendWarningsToSnapshot(
    Map<String, Object?>? snapshot,
    List<Map<String, Object?>> warnings,
  ) {
    if (snapshot == null || warnings.isEmpty) {
      return snapshot;
    }
    final existingWarnings =
        (snapshot['warnings'] as List<Object?>? ?? const [])
            .whereType<Map<Object?, Object?>>()
            .map((entry) => Map<String, Object?>.from(entry))
            .toList(growable: true);
    existingWarnings.addAll(
      warnings.map((warning) => Map<String, Object?>.from(warning)),
    );
    return <String, Object?>{...snapshot, 'warnings': existingWarnings};
  }

  String? _stringParameter(CockpitCommand command, String key) {
    final value = command.parameters[key];
    if (value is String && value.isNotEmpty) {
      return value;
    }
    return null;
  }

  bool? _boolParameter(CockpitCommand command, String key) {
    final value = command.parameters[key];
    if (value is bool) {
      return value;
    }
    if (value is String) {
      switch (value.trim().toLowerCase()) {
        case 'true':
        case '1':
        case 'yes':
        case 'y':
        case 'on':
          return true;
        case 'false':
        case '0':
        case 'no':
        case 'n':
        case 'off':
          return false;
      }
    }
    return null;
  }

  PointerDeviceKind _pointerDeviceKindParameter(
    CockpitCommand command, {
    bool allowTrackpad = false,
  }) {
    final rawValue = command.parameters['deviceKind'];
    if (rawValue == null) {
      return PointerDeviceKind.touch;
    }
    final value = switch (rawValue) {
      PointerDeviceKind() => rawValue,
      String() => switch (rawValue.trim().toLowerCase()) {
          'touch' => PointerDeviceKind.touch,
          'mouse' => PointerDeviceKind.mouse,
          'stylus' => PointerDeviceKind.stylus,
          'invertedstylus' ||
          'inverted_stylus' =>
            PointerDeviceKind.invertedStylus,
          'trackpad' => PointerDeviceKind.trackpad,
          'unknown' => PointerDeviceKind.unknown,
          _ => throw ArgumentError(
              'deviceKind must be one of touch, mouse, stylus, invertedStylus, trackpad, or unknown.',
            ),
        },
      _ => throw ArgumentError('deviceKind must be a string.'),
    };
    if (value == PointerDeviceKind.trackpad && !allowTrackpad) {
      throw ArgumentError(
        '${command.commandType.name} does not support deviceKind "trackpad". Use panZoom or a directional gesture that can map to trackpad pan/zoom events.',
      );
    }
    return value;
  }

  int _buttonsParameter(CockpitCommand command) {
    final rawValue =
        command.parameters['buttons'] ?? command.parameters['button'];
    if (rawValue == null) {
      return kPrimaryButton;
    }
    if (rawValue is int) {
      if (rawValue <= 0) {
        throw ArgumentError('buttons must be a positive integer bitmask.');
      }
      return rawValue;
    }
    if (rawValue is! String) {
      throw ArgumentError('buttons must be an integer or a string alias.');
    }

    final normalized = rawValue.trim().toLowerCase();
    if (normalized.isEmpty) {
      throw ArgumentError('buttons must not be empty.');
    }
    var mask = 0;
    for (final token in normalized.split(RegExp(r'[\s,+|]+'))) {
      if (token.isEmpty) {
        continue;
      }
      mask |= switch (token) {
        'primary' || 'left' || 'tap' => kPrimaryButton,
        'secondary' || 'right' => kSecondaryButton,
        'tertiary' || 'middle' => kTertiaryButton,
        'back' => kBackMouseButton,
        'forward' => kForwardMouseButton,
        _ => throw ArgumentError(
            'buttons must use aliases primary, secondary, tertiary, back, or forward.',
          ),
      };
    }
    if (mask <= 0) {
      throw ArgumentError('buttons must resolve to at least one input button.');
    }
    return mask;
  }

  AxisDirection? _axisDirectionParameter(Object? value) {
    return switch (value) {
      'left' => AxisDirection.left,
      'right' => AxisDirection.right,
      'up' => AxisDirection.up,
      'down' => AxisDirection.down,
      _ => null,
    };
  }

  bool _visibleTargetsContainText(
    Iterable<CockpitTarget> visibleTargets,
    String expectedText,
  ) {
    return visibleTargets.any(
      (target) => _targetContainsText(target, expectedText),
    );
  }

  List<String> _visibleTextCandidates(Iterable<CockpitTarget> visibleTargets) {
    final candidates = <String>{};
    for (final target in visibleTargets) {
      for (final value in <String?>[
        target.text,
        target.tooltip,
        target.displayLabel,
      ]) {
        if (value != null && value.isNotEmpty) {
          candidates.add(value);
        }
      }
    }
    return candidates.toList(growable: false);
  }

  bool _targetContainsText(CockpitTarget target, String expectedText) {
    return <String?>[
      target.text,
      target.tooltip,
      target.displayLabel,
    ].any((candidate) => _textSignalMatches(candidate, expectedText));
  }

  bool _textSignalMatches(String? candidate, String expectedText) {
    final normalizedCandidate = _normalizeText(candidate);
    final normalizedExpected = _normalizeText(expectedText);
    if (normalizedCandidate == null || normalizedExpected == null) {
      return false;
    }
    if (normalizedCandidate == normalizedExpected) {
      return true;
    }
    return normalizedCandidate.contains(normalizedExpected);
  }

  String? _normalizeText(String? value) {
    if (value == null) {
      return null;
    }
    final normalized = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    return normalized.isEmpty ? null : normalized;
  }

  String? _describeWaitCondition(CockpitCommand command) {
    final routeName = _expectedRouteName(command);
    if (routeName != null) {
      return 'route "$routeName"';
    }
    final expectedText = _expectedText(command);
    if (expectedText != null) {
      return 'text "$expectedText"';
    }
    final locator = command.locator;
    if (locator != null) {
      return '${locator.kind.name} "${locator.value}"';
    }
    return null;
  }

  Future<void> _settleBeforeObservation() async {
    await _settleCoordinator.settleBeforeObservation();
  }

  Future<void> _bestEffortWaitForUiIdle({
    required bool includeNetworkIdle,
  }) async {
    await _settleCoordinator.bestEffortWaitForUiIdle(
      includeNetworkIdle: includeNetworkIdle,
    );
  }

  Future<bool> _waitForRouteTargets(String? previousRouteName) async {
    if (previousRouteName == null) {
      return false;
    }

    SchedulerBinding schedulerBinding;
    WidgetsBinding widgetsBinding;
    try {
      schedulerBinding = SchedulerBinding.instance;
      widgetsBinding = WidgetsBinding.instance;
    } on Object {
      return false;
    }
    if (_isTestBinding(widgetsBinding)) {
      return false;
    }

    for (var attempt = 0; attempt < 8; attempt += 1) {
      await Future<void>.microtask(() {});
      if (schedulerBinding.schedulerPhase != SchedulerPhase.idle ||
          schedulerBinding.hasScheduledFrame) {
        await _awaitFrameIfScheduled(schedulerBinding, widgetsBinding);
      }

      final snapshot = _liveSnapshot();
      final routeChanged = snapshot.routeName != previousRouteName;
      if (routeChanged && snapshot.visibleTargets.isNotEmpty) {
        return true;
      }
      if (routeChanged && !schedulerBinding.hasScheduledFrame) {
        return true;
      }

      if (!routeChanged &&
          !schedulerBinding.hasScheduledFrame &&
          attempt >= 1) {
        return false;
      }

      if (schedulerBinding.hasScheduledFrame) {
        await _awaitFrameIfScheduled(schedulerBinding, widgetsBinding);
      } else {
        await Future<void>.delayed(const Duration(milliseconds: 16));
      }
    }
    return _liveSnapshot().routeName != previousRouteName;
  }

  Future<void> _waitForVisualContinuity({
    required CockpitCommandType? commandType,
    required bool routeChanged,
  }) async {
    if (_usesTestBinding() && !_hasCustomWaitTickHandler) {
      return;
    }
    final delay = _visualContinuityDelay(
      commandType: commandType,
      routeChanged: routeChanged,
    );
    if (delay <= Duration.zero) {
      return;
    }
    await _waitTickHandler(delay);
  }

  Future<void> _waitForPreActionContinuity(
    CockpitCommand command, {
    required CockpitCommandType commandType,
  }) async {
    if (_usesTestBinding() && !_hasCustomWaitTickHandler) {
      return;
    }
    final delay = _preActionVisualDelay(command, commandType: commandType);
    if (delay <= Duration.zero) {
      return;
    }
    await _waitTickHandler(delay);
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
      CockpitCommandType.back =>
        true,
      _ => false,
    };
    if (!isVisualMutation) {
      return Duration.zero;
    }
    return _durationFromOptionalPositiveInt(
      command,
      key: 'preActionVisualDelayMs',
      fallback: _isRecordingActive()
          ? _maxDuration(
              _interactionPolicy.preActionVisualDelay,
              _interactionPolicy.recordingPreActionVisualDelay,
            )
          : _interactionPolicy.preActionVisualDelay,
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
      CockpitCommandType.back =>
        true,
      _ => false,
    };
    if (!isVisualMutation && !routeChanged) {
      return Duration.zero;
    }
    if (_isRecordingActive()) {
      return routeChanged
          ? _maxDuration(
              _interactionPolicy.routeTransitionVisualDelay,
              _interactionPolicy.recordingActionVisualDelay,
            )
          : _interactionPolicy.recordingActionVisualDelay;
    }
    return routeChanged
        ? _interactionPolicy.routeTransitionVisualDelay
        : _interactionPolicy.actionVisualDelay;
  }

  Duration _maxDuration(Duration left, Duration right) {
    return left >= right ? left : right;
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

  static bool _isTestBinding(WidgetsBinding widgetsBinding) {
    return widgetsBinding.runtimeType.toString().contains(
          'TestWidgetsFlutterBinding',
        );
  }

  static bool _defaultRecordingActivityProbe() => false;

  static bool _usesTestBinding() {
    try {
      return _isTestBinding(WidgetsBinding.instance);
    } on Object {
      return false;
    }
  }

  static CockpitSnapshotProvider _defaultSnapshotProvider(
    CockpitTargetRegistry registry,
  ) {
    return ({options = const CockpitSnapshotOptions()}) => registry.snapshot();
  }

  CockpitSnapshot _liveSnapshot() {
    return _snapshotProvider(options: const CockpitSnapshotOptions.live());
  }

  CockpitSnapshotOptions _defaultSnapshotOptionsForReason(
    CockpitScreenshotReason reason,
  ) {
    return switch (reason) {
      CockpitScreenshotReason.assertionFailure =>
        const CockpitSnapshotOptions.investigate(),
      CockpitScreenshotReason.baseline =>
        const CockpitSnapshotOptions.baseline(),
      CockpitScreenshotReason.acceptance =>
        const CockpitSnapshotOptions.investigate(),
      CockpitScreenshotReason.beforeAction ||
      CockpitScreenshotReason.afterAction =>
        const CockpitSnapshotOptions.live(),
    };
  }
}

final class _CockpitGesturePreflightResult {
  const _CockpitGesturePreflightResult._({
    this.error,
    this.warning,
    this.degradationReason,
  });

  const _CockpitGesturePreflightResult.error(CockpitCommandError error)
      : this._(error: error);

  const _CockpitGesturePreflightResult.warning(Map<String, Object?> warning)
      : this._(warning: warning, degradationReason: 'hitTestMissWarning');

  final CockpitCommandError? error;
  final Map<String, Object?>? warning;
  final String? degradationReason;
}
