import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../control/cockpit_command_type.dart';

final class CockpitSemanticsTargetInfo {
  const CockpitSemanticsTargetInfo({
    required this.nodeId,
    required this.owner,
    required this.label,
    required this.value,
    required this.hint,
    required this.tooltip,
    required this.identifier,
    required this.supportedActions,
  });

  final int nodeId;
  final SemanticsOwner owner;
  final String? label;
  final String? value;
  final String? hint;
  final String? tooltip;
  final String? identifier;
  final Set<SemanticsAction> supportedActions;

  bool supports(SemanticsAction action) => supportedActions.contains(action);

  Set<CockpitCommandType> get supportedCommands => <CockpitCommandType>{
        if (supports(SemanticsAction.tap)) CockpitCommandType.tap,
        if (supports(SemanticsAction.longPress)) CockpitCommandType.longPress,
        if (supports(SemanticsAction.setText)) CockpitCommandType.enterText,
        if (supports(SemanticsAction.showOnScreen))
          CockpitCommandType.showOnScreen,
        if (supports(SemanticsAction.increase)) CockpitCommandType.increase,
        if (supports(SemanticsAction.decrease)) CockpitCommandType.decrease,
        if (supports(SemanticsAction.dismiss)) CockpitCommandType.dismiss,
      };

  VoidCallback? actionHandler(SemanticsAction action) {
    if (!supports(action)) {
      return null;
    }
    return () => owner.performAction(nodeId, action);
  }

  void performAction(SemanticsAction action, [Object? args]) {
    if (!supports(action)) {
      throw StateError('Semantics node $nodeId does not support $action.');
    }
    owner.performAction(nodeId, action, args);
  }
}

CockpitSemanticsTargetInfo? cockpitResolveSemanticsTargetInfo(Element element) {
  final node = _resolveSemanticsNode(element);
  final owner = node?.owner;
  if (node == null || owner == null) {
    return null;
  }
  final data = node.getSemanticsData();
  return CockpitSemanticsTargetInfo(
    nodeId: node.id,
    owner: owner,
    label: _normalizeSemanticsValue(data.label),
    value: _normalizeSemanticsValue(data.value),
    hint: _normalizeSemanticsValue(data.hint),
    tooltip: _normalizeSemanticsValue(data.tooltip),
    identifier: _normalizeSemanticsValue(data.identifier),
    supportedActions: _supportedActionsFrom(data),
  );
}

SemanticsAction? cockpitResolveSemanticScrollAction({
  required AxisDirection axisDirection,
  required bool forward,
}) {
  return switch ((axisDirection, forward)) {
    (AxisDirection.down, true) => SemanticsAction.scrollUp,
    (AxisDirection.down, false) => SemanticsAction.scrollDown,
    (AxisDirection.up, true) => SemanticsAction.scrollDown,
    (AxisDirection.up, false) => SemanticsAction.scrollUp,
    (AxisDirection.right, true) => SemanticsAction.scrollLeft,
    (AxisDirection.right, false) => SemanticsAction.scrollRight,
    (AxisDirection.left, true) => SemanticsAction.scrollRight,
    (AxisDirection.left, false) => SemanticsAction.scrollLeft,
  };
}

SemanticsNode? _resolveSemanticsNode(Element element) {
  RenderObject? renderObject = element.findRenderObject();
  SemanticsNode? result = renderObject?.debugSemantics;
  while (
      renderObject != null && (result == null || result.isMergedIntoParent)) {
    renderObject = renderObject.parent;
    result = renderObject?.debugSemantics;
  }
  return result;
}

Set<SemanticsAction> _supportedActionsFrom(SemanticsData data) {
  return SemanticsAction.values.where(data.hasAction).toSet();
}

String? _normalizeSemanticsValue(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }
  return trimmed;
}
