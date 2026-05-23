import 'package:flutter/widgets.dart' show Element, debugOnRebuildDirtyWidget;

typedef CockpitDirtyWidgetCallback =
    void Function(Element element, bool builtOnce);

final class CockpitBuildOwner {
  CockpitBuildOwner({required CockpitDirtyWidgetCallback onRebuildDirtyWidget})
    : _onRebuildDirtyWidget = onRebuildDirtyWidget;

  final CockpitDirtyWidgetCallback _onRebuildDirtyWidget;
  CockpitDirtyWidgetCallback? _previousCallback;
  bool _attached = false;

  void attach() {
    assert(() {
      _previousCallback = debugOnRebuildDirtyWidget;
      debugOnRebuildDirtyWidget = _handleRebuildDirtyWidget;
      _attached = true;
      return true;
    }());
  }

  void dispose() {
    assert(() {
      if (_attached &&
          identical(debugOnRebuildDirtyWidget, _handleRebuildDirtyWidget)) {
        debugOnRebuildDirtyWidget = _previousCallback;
      }
      _attached = false;
      _previousCallback = null;
      return true;
    }());
  }

  void _handleRebuildDirtyWidget(Element element, bool builtOnce) {
    _previousCallback?.call(element, builtOnce);
    _onRebuildDirtyWidget(element, builtOnce);
  }
}
