import 'package:flutter/widgets.dart';

bool cockpitIsVisibleInRuntimeTree(
  Element element, {
  bool ignoreCurrentRoute = false,
}) {
  if (!element.mounted) {
    return false;
  }

  if (!_isVisibleInAncestorTree(element)) {
    return false;
  }

  final routeScope = _nearestRouteScope(element);
  if (routeScope == null) {
    return true;
  }
  if (ignoreCurrentRoute) {
    return true;
  }
  return routeScope.isCurrent;
}

String? cockpitResolvedElementRouteName(
  Element element, {
  required String? fallbackRouteName,
}) {
  final routeName = _nearestRouteScope(element)?.route.settings.name;
  if (routeName == null || routeName.isEmpty) {
    return fallbackRouteName;
  }
  if (routeName == '/' &&
      fallbackRouteName != null &&
      fallbackRouteName != '/') {
    return fallbackRouteName;
  }
  return routeName;
}

_CockpitRouteScope? _nearestRouteScope(Element element) {
  _CockpitRouteScope? scope;
  element.visitAncestorElements((ancestor) {
    final widget = ancestor.widget;
    if (widget.runtimeType.toString() != '_ModalScopeStatus') {
      return true;
    }

    final candidate = widget as dynamic;
    scope = _CockpitRouteScope(
      route: candidate.route as Route<dynamic>,
      isCurrent: candidate.isCurrent as bool,
    );
    return false;
  });
  return scope;
}

bool _isVisibleInAncestorTree(Element element) {
  var isVisible = true;
  element.visitAncestorElements((ancestor) {
    final widget = ancestor.widget;
    if (widget is Offstage && widget.offstage) {
      isVisible = false;
      return false;
    }
    return true;
  });
  return isVisible;
}

final class _CockpitRouteScope {
  const _CockpitRouteScope({required this.route, required this.isCurrent});

  final Route<dynamic> route;
  final bool isCurrent;
}
