import 'dart:math' as math;

import 'package:cockpit_protocol/cockpit_protocol.dart';

final class CockpitTestLoweredAction {
  const CockpitTestLoweredAction({
    required this.command,
    required this.requestedPlane,
    required this.actualPlane,
  });

  final CockpitCommand command;
  final CockpitTestPlane requestedPlane;
  final CockpitTestPlane actualPlane;
}

final class CockpitTestLoweringResult {
  const CockpitTestLoweringResult.success(this.value) : error = null;

  const CockpitTestLoweringResult.failure(this.error) : value = null;

  final CockpitTestLoweredAction? value;
  final CockpitTestError? error;

  bool get isSuccess => value != null;
}

final class CockpitTestActionLowerer {
  const CockpitTestActionLowerer();

  CockpitTestLoweringResult lower({
    required CockpitTestAction action,
    required String commandId,
    required int timeoutMs,
    required CockpitTestPlane requestedPlane,
    required CockpitCapabilities capabilities,
  }) {
    if (requestedPlane != CockpitTestPlane.semantic) {
      return _failure(
        CockpitTestErrorCode.unsupportedAction,
        'The Flutter backend executes only the semantic plane; requested '
        '${requestedPlane.name}.',
      );
    }
    final locatorResult = _lowerLocator(action.locator, capabilities);
    if (locatorResult.error != null) {
      return CockpitTestLoweringResult.failure(locatorResult.error!);
    }
    if (action.kind == CockpitTestActionKind.assertText &&
        action.value<String>(CockpitTestActionField.matchMode) != null &&
        action.value<String>(CockpitTestActionField.matchMode) != 'exact') {
      return _failure(
        CockpitTestErrorCode.unsupportedAction,
        'The Flutter backend currently supports exact assertText matching.',
      );
    }
    if (action.kind == CockpitTestActionKind.setTextEditingValue &&
        (action.values.containsKey(CockpitTestActionField.composingStart) ||
            action.values.containsKey(CockpitTestActionField.composingEnd))) {
      return _failure(
        CockpitTestErrorCode.unsupportedAction,
        'The Flutter backend does not support composing ranges.',
      );
    }
    if (action.kind == CockpitTestActionKind.scrollUntilVisible) {
      final direction = action.value<String>(CockpitTestActionField.direction);
      if (direction == 'left' || direction == 'right') {
        return _failure(
          CockpitTestErrorCode.unsupportedAction,
          'The Flutter backend currently supports vertical scrolling only.',
        );
      }
    }
    if (action.kind == CockpitTestActionKind.swipe) {
      final distance = action
          .value<num>(CockpitTestActionField.distance)!
          .toDouble();
      if (distance < 0.15 || distance > 0.95) {
        return _failure(
          CockpitTestErrorCode.unsupportedAction,
          'The Flutter backend supports swipe distance from 0.15 through '
          '0.95 without parameter coercion.',
        );
      }
    }
    if (action.kind == CockpitTestActionKind.fling) {
      final dx = action.value<num>(CockpitTestActionField.dx)!.toDouble();
      final dy = action.value<num>(CockpitTestActionField.dy)!.toDouble();
      final velocity = action
          .value<num>(CockpitTestActionField.velocity)!
          .toDouble();
      if ((math.sqrt(dx * dx + dy * dy) / velocity * 1000).round() <= 0) {
        return _failure(
          CockpitTestErrorCode.unsupportedAction,
          'The Flutter backend cannot represent this fling velocity.',
        );
      }
    }
    if (action.kind == CockpitTestActionKind.waitFor) {
      return lowerCondition(
        condition: action.condition!,
        commandId: commandId,
        timeoutMs: timeoutMs,
        requestedPlane: requestedPlane,
        capabilities: capabilities,
      );
    }
    final commandType = _commandType(action);
    if (!capabilities.supportedCommands.contains(commandType)) {
      return _failure(
        CockpitTestErrorCode.unsupportedAction,
        'Target does not support ${action.kind.name}.',
      );
    }
    final parameters = _parameters(action);
    final command = CockpitCommand(
      commandId: commandId,
      commandType: commandType,
      locator: locatorResult.locator,
      parameters: parameters,
      capturePolicy: CockpitCapturePolicy.none,
      timeoutMs: timeoutMs,
      snapshotOptions: _snapshotOptions(action),
      screenshotRequest: _screenshotRequest(action),
    );
    return CockpitTestLoweringResult.success(
      CockpitTestLoweredAction(
        command: command,
        requestedPlane: requestedPlane,
        actualPlane: CockpitTestPlane.semantic,
      ),
    );
  }

  CockpitTestLoweringResult lowerCondition({
    required CockpitTestCondition condition,
    required String commandId,
    required int timeoutMs,
    required CockpitTestPlane requestedPlane,
    required CockpitCapabilities capabilities,
  }) {
    if (requestedPlane != CockpitTestPlane.semantic) {
      return _failure(
        CockpitTestErrorCode.unsupportedAction,
        'Condition cannot execute on ${requestedPlane.name} in Flutter.',
      );
    }
    final locatorResult = _lowerLocator(condition.locator, capabilities);
    if (locatorResult.error != null) {
      return CockpitTestLoweringResult.failure(locatorResult.error!);
    }
    if (condition.kind == CockpitTestConditionKind.text &&
        condition.matchMode != null &&
        condition.matchMode != CockpitTestTextMatchMode.exact) {
      return _failure(
        CockpitTestErrorCode.unsupportedAction,
        'The Flutter backend currently supports exact text conditions.',
      );
    }
    final commandType = switch (condition.kind) {
      CockpitTestConditionKind.visible ||
      CockpitTestConditionKind.route => CockpitCommandType.waitFor,
      CockpitTestConditionKind.text => CockpitCommandType.assertText,
      CockpitTestConditionKind.uiIdle => CockpitCommandType.waitForUiIdle,
      CockpitTestConditionKind.networkIdle =>
        CockpitCommandType.waitForNetworkIdle,
    };
    if (!capabilities.supportedCommands.contains(commandType)) {
      return _failure(
        CockpitTestErrorCode.unsupportedAction,
        'Target does not support ${condition.kind.name} conditions.',
      );
    }
    return CockpitTestLoweringResult.success(
      CockpitTestLoweredAction(
        command: CockpitCommand(
          commandId: commandId,
          commandType: commandType,
          locator: locatorResult.locator,
          parameters: _conditionParameters(condition),
          capturePolicy: CockpitCapturePolicy.none,
          timeoutMs: timeoutMs,
        ),
        requestedPlane: requestedPlane,
        actualPlane: CockpitTestPlane.semantic,
      ),
    );
  }

  CockpitTestLoweringResult _failure(
    CockpitTestErrorCode code,
    String message,
  ) => CockpitTestLoweringResult.failure(
    CockpitTestError(code: code, message: message),
  );
}

final class _LocatorLoweringResult {
  const _LocatorLoweringResult.success(this.locator) : error = null;
  const _LocatorLoweringResult.failure(this.error) : locator = null;

  final CockpitLocator? locator;
  final CockpitTestError? error;
}

_LocatorLoweringResult _lowerLocator(
  CockpitTestLocator? locator,
  CockpitCapabilities capabilities,
) {
  if (locator == null) {
    return const _LocatorLoweringResult.success(null);
  }
  final kind = switch (locator.strategy) {
    CockpitTestLocatorStrategy.text => CockpitLocatorKind.text,
    CockpitTestLocatorStrategy.label => CockpitLocatorKind.tooltip,
    CockpitTestLocatorStrategy.testId => CockpitLocatorKind.cockpitId,
    CockpitTestLocatorStrategy.type => CockpitLocatorKind.type,
    CockpitTestLocatorStrategy.path => CockpitLocatorKind.path,
    CockpitTestLocatorStrategy.nativeId ||
    CockpitTestLocatorStrategy.role ||
    CockpitTestLocatorStrategy.coordinate ||
    CockpitTestLocatorStrategy.visual => null,
  };
  if (kind == null) {
    return _LocatorLoweringResult.failure(
      CockpitTestError(
        code: CockpitTestErrorCode.unsupportedLocator,
        message:
            'The Flutter backend cannot faithfully lower locator strategy '
            '${locator.strategy.name}.',
      ),
    );
  }
  if (!capabilities.supportedLocatorStrategies.contains(kind)) {
    return _LocatorLoweringResult.failure(
      CockpitTestError(
        code: CockpitTestErrorCode.unsupportedLocator,
        message: 'Target does not support locator strategy ${kind.name}.',
      ),
    );
  }
  CockpitLocator? ancestor;
  if (locator.ancestor != null) {
    final lowered = _lowerLocator(locator.ancestor, capabilities);
    if (lowered.error != null) {
      return lowered;
    }
    ancestor = lowered.locator;
  }
  final fallbacks = <CockpitLocator>[];
  for (final fallback in locator.fallbacks) {
    final lowered = _lowerLocator(fallback, capabilities);
    if (lowered.error != null) {
      return lowered;
    }
    fallbacks.add(lowered.locator!);
  }
  final value = locator.value!;
  return _LocatorLoweringResult.success(
    CockpitLocator(
      cockpitId: kind == CockpitLocatorKind.cockpitId ? value : null,
      text: kind == CockpitLocatorKind.text ? value : null,
      tooltip: kind == CockpitLocatorKind.tooltip ? value : null,
      type: kind == CockpitLocatorKind.type ? value : null,
      path: kind == CockpitLocatorKind.path ? value : null,
      index: locator.index,
      ancestor: ancestor,
      fallbacks: fallbacks,
    ),
  );
}

CockpitCommandType _commandType(
  CockpitTestAction action,
) => switch (action.kind) {
  CockpitTestActionKind.tap => CockpitCommandType.tap,
  CockpitTestActionKind.longPress => CockpitCommandType.longPress,
  CockpitTestActionKind.doubleTap => CockpitCommandType.doubleTap,
  CockpitTestActionKind.enterText => CockpitCommandType.enterText,
  CockpitTestActionKind.focusTextInput => CockpitCommandType.focusTextInput,
  CockpitTestActionKind.setTextEditingValue =>
    CockpitCommandType.setTextEditingValue,
  CockpitTestActionKind.sendTextInputAction =>
    CockpitCommandType.sendTextInputAction,
  CockpitTestActionKind.sendKeyEvent => CockpitCommandType.sendKeyEvent,
  CockpitTestActionKind.sendKeyDownEvent => CockpitCommandType.sendKeyDownEvent,
  CockpitTestActionKind.sendKeyUpEvent => CockpitCommandType.sendKeyUpEvent,
  CockpitTestActionKind.drag => CockpitCommandType.drag,
  CockpitTestActionKind.fling => CockpitCommandType.fling,
  CockpitTestActionKind.swipe => CockpitCommandType.swipe,
  CockpitTestActionKind.pinchZoom => CockpitCommandType.pinchZoom,
  CockpitTestActionKind.rotate => CockpitCommandType.rotate,
  CockpitTestActionKind.panZoom => CockpitCommandType.panZoom,
  CockpitTestActionKind.multiTouch => CockpitCommandType.multiTouch,
  CockpitTestActionKind.scrollUntilVisible =>
    CockpitCommandType.scrollUntilVisible,
  CockpitTestActionKind.back => CockpitCommandType.back,
  CockpitTestActionKind.showOnScreen => CockpitCommandType.showOnScreen,
  CockpitTestActionKind.increase => CockpitCommandType.increase,
  CockpitTestActionKind.decrease => CockpitCommandType.decrease,
  CockpitTestActionKind.dismiss => CockpitCommandType.dismiss,
  CockpitTestActionKind.dismissKeyboard => CockpitCommandType.dismissKeyboard,
  CockpitTestActionKind.clearNetworkActivity =>
    CockpitCommandType.clearNetworkActivity,
  CockpitTestActionKind.waitForNetworkIdle =>
    CockpitCommandType.waitForNetworkIdle,
  CockpitTestActionKind.waitForUiIdle => CockpitCommandType.waitForUiIdle,
  CockpitTestActionKind.assertVisible =>
    action.value<bool>(CockpitTestActionField.expected) == false
        ? CockpitCommandType.waitFor
        : CockpitCommandType.assertVisible,
  CockpitTestActionKind.assertText => CockpitCommandType.assertText,
  CockpitTestActionKind.captureScreenshot =>
    CockpitCommandType.captureScreenshot,
  CockpitTestActionKind.collectSnapshot => CockpitCommandType.collectSnapshot,
  CockpitTestActionKind.waitFor => throw StateError(
    'waitFor is lowered through its condition.',
  ),
};

Map<String, Object?> _parameters(CockpitTestAction action) {
  final parameters = <String, Object?>{};
  for (final entry in action.values.entries) {
    switch (entry.key) {
      case CockpitTestActionField.keyRequest:
        parameters.addAll(
          Map<String, Object?>.from(entry.value! as Map<Object?, Object?>),
        );
      case CockpitTestActionField.selectionStart:
        parameters['selectionBase'] = entry.value;
      case CockpitTestActionField.selectionEnd:
        parameters['selectionExtent'] = entry.value;
      case CockpitTestActionField.composingStart ||
          CockpitTestActionField.composingEnd:
        throw const FormatException(
          'The Flutter backend does not support composing ranges.',
        );
      case CockpitTestActionField.distance:
        parameters['distanceFactor'] = entry.value;
      case CockpitTestActionField.direction:
        if (action.kind == CockpitTestActionKind.scrollUntilVisible) {
          parameters['reverse'] = entry.value == 'up';
        } else {
          parameters[entry.key.wireName] = entry.value;
        }
      case CockpitTestActionField.velocity:
        break;
      case CockpitTestActionField.artifactName:
        parameters['name'] = entry.value;
      case CockpitTestActionField.captureOptions ||
          CockpitTestActionField.snapshotOptions ||
          CockpitTestActionField.expected ||
          CockpitTestActionField.matchMode:
        break;
      default:
        parameters[entry.key.wireName] = entry.value;
    }
  }
  if (action.kind == CockpitTestActionKind.fling) {
    final dx = action.value<num>(CockpitTestActionField.dx)!.toDouble();
    final dy = action.value<num>(CockpitTestActionField.dy)!.toDouble();
    final velocity = action
        .value<num>(CockpitTestActionField.velocity)!
        .toDouble();
    final distance = math.sqrt(dx * dx + dy * dy);
    parameters['durationMs'] = (distance / velocity * 1000).round();
  }
  if (action.kind == CockpitTestActionKind.assertVisible &&
      action.value<bool>(CockpitTestActionField.expected) == false) {
    parameters['absent'] = true;
  }
  return Map<String, Object?>.unmodifiable(parameters);
}

Map<String, Object?> _conditionParameters(CockpitTestCondition condition) =>
    switch (condition.kind) {
      CockpitTestConditionKind.visible => <String, Object?>{
        if (condition.expected == false) 'absent': true,
      },
      CockpitTestConditionKind.text => <String, Object?>{
        'text': condition.text,
      },
      CockpitTestConditionKind.route => <String, Object?>{
        'routeName': condition.route,
      },
      CockpitTestConditionKind.uiIdle ||
      CockpitTestConditionKind.networkIdle => <String, Object?>{
        if (condition.quietMs != null) 'quietMs': condition.quietMs,
      },
    };

CockpitSnapshotOptions? _snapshotOptions(CockpitTestAction action) {
  final value = action.values[CockpitTestActionField.snapshotOptions];
  return value is Map<Object?, Object?>
      ? CockpitSnapshotOptions.fromJson(Map<String, Object?>.from(value))
      : null;
}

CockpitScreenshotRequest? _screenshotRequest(CockpitTestAction action) {
  if (action.kind != CockpitTestActionKind.captureScreenshot) {
    return null;
  }
  final options = action.values[CockpitTestActionField.captureOptions];
  final json = options is Map<Object?, Object?>
      ? Map<String, Object?>.from(options)
      : <String, Object?>{};
  return CockpitScreenshotRequest(
    reason: json['reason'] == null
        ? CockpitScreenshotReason.acceptance
        : CockpitScreenshotReason.fromJson(json['reason']),
    name: action.value<String>(CockpitTestActionField.artifactName)!,
    includeSnapshot: json['includeSnapshot'] as bool? ?? false,
    attachToStep: json['attachToStep'] as bool? ?? true,
    snapshotOptions: json['snapshotOptions'] is Map<Object?, Object?>
        ? CockpitSnapshotOptions.fromJson(
            Map<String, Object?>.from(
              json['snapshotOptions']! as Map<Object?, Object?>,
            ),
          )
        : null,
    profile: json['profile'] == null
        ? null
        : CockpitCaptureProfile.fromJson(json['profile']),
    allowFallback: json['allowFallback'] as bool?,
  );
}
