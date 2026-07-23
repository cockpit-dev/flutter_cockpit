import 'package:cockpit_protocol/cockpit_protocol.dart';
import 'package:collection/collection.dart';
import 'package:xml/xml.dart';

final class CockpitNativeUiSnapshot {
  CockpitNativeUiSnapshot._({
    required this.raw,
    required this.nodes,
    required this.viewportWidth,
    required this.viewportHeight,
  });

  final String raw;
  final List<CockpitNativeUiNode> nodes;
  final int viewportWidth;
  final int viewportHeight;

  factory CockpitNativeUiSnapshot.parse(String raw) {
    final document = XmlDocument.parse(raw);
    final nodes = <CockpitNativeUiNode>[];

    void visit(XmlElement element, List<String> ancestorPaths) {
      var elementIndex = 0;
      final parent = element.parentElement;
      if (parent != null) {
        for (final sibling in parent.childElements) {
          if (identical(sibling, element)) break;
          if (sibling.name.local == element.name.local) elementIndex += 1;
        }
      }
      final path = <String>[
        ...ancestorPaths,
        '${element.name.local}[$elementIndex]',
      ].join('/');
      final attributes = <String, String>{
        for (final attribute in element.attributes)
          attribute.name.local.toLowerCase(): attribute.value,
      };
      final bounds = _readBounds(attributes);
      nodes.add(
        CockpitNativeUiNode(
          path: '/$path',
          ancestorPaths: List<String>.unmodifiable(<String>[
            for (var index = 0; index < ancestorPaths.length; index += 1)
              '/${ancestorPaths.take(index + 1).join('/')}',
          ]),
          elementName: element.name.local,
          attributes: Map<String, String>.unmodifiable(attributes),
          bounds: bounds,
        ),
      );
      for (final child in element.childElements) {
        visit(child, <String>[
          ...ancestorPaths,
          '${element.name.local}[$elementIndex]',
        ]);
      }
    }

    visit(document.rootElement, const <String>[]);
    var width = 0;
    var height = 0;
    for (final node in nodes) {
      final bounds = node.bounds;
      if (bounds == null) continue;
      if (bounds.right > width) width = bounds.right;
      if (bounds.bottom > height) height = bounds.bottom;
    }
    if (width <= 0 || height <= 0) {
      throw const FormatException(
        'Native UI tree does not contain a usable viewport.',
      );
    }
    return CockpitNativeUiSnapshot._(
      raw: raw,
      nodes: List<CockpitNativeUiNode>.unmodifiable(nodes),
      viewportWidth: width,
      viewportHeight: height,
    );
  }

  CockpitNativeUiResolution resolve(CockpitTestLocator locator) {
    for (final candidate in locator.flattened) {
      if (candidate.strategy == CockpitTestLocatorStrategy.coordinate) {
        return CockpitNativeUiResolution.coordinate(
          locator: candidate,
          x: (candidate.x! * viewportWidth).round().clamp(0, viewportWidth - 1),
          y: (candidate.y! * viewportHeight).round().clamp(
            0,
            viewportHeight - 1,
          ),
        );
      }
      if (candidate.strategy == CockpitTestLocatorStrategy.visual) continue;
      final matches = nodes
          .where((node) => node.visible && _matches(node, candidate))
          .where((node) => _matchesAncestor(node, candidate.ancestor))
          .toList(growable: false);
      final index = candidate.index;
      if (index != null) {
        if (index < matches.length) {
          return CockpitNativeUiResolution.node(
            locator: candidate,
            node: matches[index],
          );
        }
        continue;
      }
      if (matches.length == 1) {
        return CockpitNativeUiResolution.node(
          locator: candidate,
          node: matches.single,
        );
      }
      if (matches.length > 1) {
        return CockpitNativeUiResolution.ambiguous(
          locator: candidate,
          matchCount: matches.length,
        );
      }
    }
    return CockpitNativeUiResolution.notFound(locator);
  }

  bool _matchesAncestor(CockpitNativeUiNode node, CockpitTestLocator? locator) {
    if (locator == null) return true;
    for (final ancestorPath in node.ancestorPaths.reversed) {
      final ancestor = nodes
          .where((candidate) => candidate.path == ancestorPath)
          .firstOrNull;
      if (ancestor != null && _matches(ancestor, locator)) return true;
    }
    return false;
  }

  bool _matches(CockpitNativeUiNode node, CockpitTestLocator locator) {
    final expected = locator.value ?? '';
    return switch (locator.strategy) {
      CockpitTestLocatorStrategy.text => node.textValues.contains(expected),
      CockpitTestLocatorStrategy.label => node.labelValues.contains(expected),
      CockpitTestLocatorStrategy.nativeId => node.nativeIds.contains(expected),
      CockpitTestLocatorStrategy.testId => node.testIds.contains(expected),
      CockpitTestLocatorStrategy.role => node.roles.any(
        (role) => _typeMatches(role, expected),
      ),
      CockpitTestLocatorStrategy.type => node.types.any(
        (type) => _typeMatches(type, expected),
      ),
      CockpitTestLocatorStrategy.path => node.path == expected,
      CockpitTestLocatorStrategy.coordinate ||
      CockpitTestLocatorStrategy.visual => false,
    };
  }
}

final class CockpitNativeUiNode {
  const CockpitNativeUiNode({
    required this.path,
    required this.ancestorPaths,
    required this.elementName,
    required this.attributes,
    required this.bounds,
  });

  final String path;
  final List<String> ancestorPaths;
  final String elementName;
  final Map<String, String> attributes;
  final CockpitNativeUiBounds? bounds;

  bool get visible {
    final visible = attributes['visible'] ?? attributes['visible-to-user'];
    return visible?.toLowerCase() != 'false' && bounds?.hasArea == true;
  }

  Set<String> get textValues =>
      _values(<String>['text', 'value', 'label', 'name']);

  Set<String> get labelValues =>
      _values(<String>['content-desc', 'label', 'name', 'hint']);

  Set<String> get nativeIds =>
      _values(<String>['resource-id', 'name', 'identifier', 'id']);

  Set<String> get testIds =>
      _values(<String>['resource-id', 'name', 'identifier', 'testid']);

  Set<String> get roles => _values(<String>['role', 'type', 'class']);

  Set<String> get types => <String>{
    elementName,
    ..._values(<String>['type', 'class']),
  };

  Set<String> _values(List<String> keys) => keys
      .map((key) => attributes[key]?.trim())
      .whereType<String>()
      .where((value) => value.isNotEmpty)
      .toSet();
}

final class CockpitNativeUiBounds {
  const CockpitNativeUiBounds({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  final int left;
  final int top;
  final int right;
  final int bottom;

  bool get hasArea => right > left && bottom > top;
  int get centerX => left + ((right - left) / 2).round();
  int get centerY => top + ((bottom - top) / 2).round();
}

final class CockpitNativeUiResolution {
  const CockpitNativeUiResolution._({
    required this.locator,
    this.node,
    this.x,
    this.y,
    this.matchCount = 0,
  });

  const CockpitNativeUiResolution.node({
    required CockpitTestLocator locator,
    required CockpitNativeUiNode node,
  }) : this._(locator: locator, node: node, matchCount: 1);

  const CockpitNativeUiResolution.coordinate({
    required CockpitTestLocator locator,
    required int x,
    required int y,
  }) : this._(locator: locator, x: x, y: y, matchCount: 1);

  const CockpitNativeUiResolution.ambiguous({
    required CockpitTestLocator locator,
    required int matchCount,
  }) : this._(locator: locator, matchCount: matchCount);

  const CockpitNativeUiResolution.notFound(CockpitTestLocator locator)
    : this._(locator: locator);

  final CockpitTestLocator locator;
  final CockpitNativeUiNode? node;
  final int? x;
  final int? y;
  final int matchCount;

  bool get found => node != null || (x != null && y != null);
  bool get ambiguous => !found && matchCount > 1;
  int? get centerX => x ?? node?.bounds?.centerX;
  int? get centerY => y ?? node?.bounds?.centerY;
}

CockpitNativeUiBounds? _readBounds(Map<String, String> attributes) {
  final android = attributes['bounds'];
  if (android != null) {
    final match = RegExp(
      r'^\[(-?\d+),(-?\d+)\]\[(-?\d+),(-?\d+)\]$',
    ).firstMatch(android.trim());
    if (match != null) {
      return CockpitNativeUiBounds(
        left: int.parse(match.group(1)!),
        top: int.parse(match.group(2)!),
        right: int.parse(match.group(3)!),
        bottom: int.parse(match.group(4)!),
      );
    }
  }
  final x = _number(attributes['x']);
  final y = _number(attributes['y']);
  final width = _number(attributes['width']);
  final height = _number(attributes['height']);
  if (x == null || y == null || width == null || height == null) return null;
  return CockpitNativeUiBounds(
    left: x.round(),
    top: y.round(),
    right: (x + width).round(),
    bottom: (y + height).round(),
  );
}

double? _number(String? value) => value == null ? null : double.tryParse(value);

bool _typeMatches(String actual, String expected) {
  final normalizedActual = actual.toLowerCase();
  final normalizedExpected = expected.toLowerCase();
  return normalizedActual == normalizedExpected ||
      normalizedActual.endsWith(normalizedExpected) ||
      normalizedActual.endsWith('type$normalizedExpected');
}
