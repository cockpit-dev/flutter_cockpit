import 'package:flutter/widgets.dart';

import 'cockpit_snapshot.dart';

CockpitFocusSnapshot cockpitBuildFocusSnapshot() {
  final primaryFocus = FocusManager.instance.primaryFocus;
  if (primaryFocus == null) {
    return const CockpitFocusSnapshot(
      hasPrimaryFocus: false,
      isTextInputFocus: false,
    );
  }

  final context = primaryFocus.context;
  final widgetType = context?.widget.runtimeType.toString();
  final elementType = context?.runtimeType.toString();

  return CockpitFocusSnapshot(
    hasPrimaryFocus: true,
    primaryFocusDebugLabel: _blankToNull(primaryFocus.debugLabel),
    primaryFocusWidgetType: _blankToNull(widgetType),
    primaryFocusElementType: _blankToNull(elementType),
    primaryFocusLabel: _primaryFocusLabel(primaryFocus, context),
    isTextInputFocus: _isTextInputFocus(primaryFocus, context),
  );
}

String? _primaryFocusLabel(FocusNode focusNode, BuildContext? context) {
  return _blankToNull(focusNode.debugLabel) ??
      _blankToNull(context?.widget.runtimeType.toString());
}

bool _isTextInputFocus(FocusNode focusNode, BuildContext? context) {
  if (focusNode is FocusScopeNode) {
    return false;
  }
  if (context is! Element) {
    return false;
  }

  var foundEditableText = false;
  var foundTextField = false;
  void inspect(Element element) {
    final widget = element.widget;
    final typeName = widget.runtimeType.toString();
    if (widget is EditableText || typeName.contains('EditableText')) {
      foundEditableText = true;
    }
    if (typeName.contains('TextField') || typeName.contains('TextFormField')) {
      foundTextField = true;
    }
  }

  inspect(context);
  if (!foundEditableText) {
    context.visitAncestorElements((ancestor) {
      inspect(ancestor);
      return !foundEditableText;
    });
  }
  return foundEditableText || foundTextField;
}

String? _blankToNull(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}
