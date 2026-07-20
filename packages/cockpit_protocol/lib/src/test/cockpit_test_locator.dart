import 'package:collection/collection.dart';

import 'cockpit_test_value.dart';
import 'cockpit_test_value_reader.dart';

enum CockpitTestLocatorStrategy {
  text,
  label,
  nativeId,
  testId,
  role,
  type,
  path,
  coordinate,
  visual,
}

final class CockpitTestLocatorTemplate {
  CockpitTestLocatorTemplate({
    required this.strategy,
    this.value,
    this.x,
    this.y,
    this.threshold,
    this.index,
    this.ancestor,
    Iterable<CockpitTestLocatorTemplate> fallbacks =
        const <CockpitTestLocatorTemplate>[],
  }) : fallbacks = List<CockpitTestLocatorTemplate>.unmodifiable(fallbacks) {
    _validateTemplate();
  }

  final CockpitTestLocatorStrategy strategy;
  final CockpitTestTemplateValue? value;
  final CockpitTestTemplateValue? x;
  final CockpitTestTemplateValue? y;
  final CockpitTestTemplateValue? threshold;
  final CockpitTestTemplateValue? index;
  final CockpitTestLocatorTemplate? ancestor;
  final List<CockpitTestLocatorTemplate> fallbacks;

  bool get degraded =>
      strategy == CockpitTestLocatorStrategy.coordinate ||
      strategy == CockpitTestLocatorStrategy.visual;

  Map<String, Object?> toJson() => <String, Object?>{
    'strategy': strategy.name,
    if (value != null) 'value': value!.toJson(),
    if (x != null) 'x': x!.toJson(),
    if (y != null) 'y': y!.toJson(),
    if (threshold != null) 'threshold': threshold!.toJson(),
    if (index != null) 'index': index!.toJson(),
    if (ancestor != null) 'ancestor': ancestor!.toJson(),
    if (fallbacks.isNotEmpty)
      'fallbacks': fallbacks.map((locator) => locator.toJson()).toList(),
  };

  factory CockpitTestLocatorTemplate.fromJson(
    Object? value, {
    required String path,
  }) {
    final json = CockpitTestValueReader.object(value, path);
    CockpitTestValueReader.keys(
      json,
      const <String>{
        'strategy',
        'value',
        'x',
        'y',
        'threshold',
        'index',
        'ancestor',
        'fallbacks',
      },
      path,
      required: const <String>{'strategy'},
    );
    final strategy = CockpitTestValueReader.enumeration(
      json['strategy'],
      CockpitTestLocatorStrategy.values,
      '$path.strategy',
    );
    final fallbacks = json['fallbacks'] == null
        ? const <CockpitTestLocatorTemplate>[]
        : <CockpitTestLocatorTemplate>[
            for (
              var index = 0;
              index <
                  CockpitTestValueReader.list(
                    json['fallbacks'],
                    '$path.fallbacks',
                  ).length;
              index += 1
            )
              CockpitTestLocatorTemplate.fromJson(
                CockpitTestValueReader.list(
                  json['fallbacks'],
                  '$path.fallbacks',
                )[index],
                path: '$path.fallbacks[$index]',
              ),
          ];
    return CockpitTestLocatorTemplate(
      strategy: strategy,
      value: json['value'] == null
          ? null
          : CockpitTestTemplateValue.fromJson(
              json['value'],
              expectedType: CockpitTestValueType.string,
              path: '$path.value',
            ),
      x: json['x'] == null
          ? null
          : CockpitTestTemplateValue.fromJson(
              json['x'],
              expectedType: CockpitTestValueType.number,
              path: '$path.x',
            ),
      y: json['y'] == null
          ? null
          : CockpitTestTemplateValue.fromJson(
              json['y'],
              expectedType: CockpitTestValueType.number,
              path: '$path.y',
            ),
      threshold: json['threshold'] == null
          ? null
          : CockpitTestTemplateValue.fromJson(
              json['threshold'],
              expectedType: CockpitTestValueType.number,
              path: '$path.threshold',
            ),
      index: json['index'] == null
          ? null
          : CockpitTestTemplateValue.fromJson(
              json['index'],
              expectedType: CockpitTestValueType.integer,
              path: '$path.index',
            ),
      ancestor: json['ancestor'] == null
          ? null
          : CockpitTestLocatorTemplate.fromJson(
              json['ancestor'],
              path: '$path.ancestor',
            ),
      fallbacks: fallbacks,
    );
  }

  void _validateTemplate() {
    final semantic =
        strategy != CockpitTestLocatorStrategy.coordinate &&
        strategy != CockpitTestLocatorStrategy.visual;
    if (semantic && value == null) {
      throw FormatException('${strategy.name} locator requires value.');
    }
    if (strategy == CockpitTestLocatorStrategy.coordinate &&
        (x == null || y == null || value != null || threshold != null)) {
      throw const FormatException(
        'A coordinate locator requires x/y and forbids value/threshold.',
      );
    }
    if (strategy == CockpitTestLocatorStrategy.visual &&
        (value == null || x != null || y != null)) {
      throw const FormatException(
        'A visual locator requires value and forbids x/y.',
      );
    }
    if (semantic && (x != null || y != null || threshold != null)) {
      throw FormatException(
        '${strategy.name} locator forbids visual coordinates.',
      );
    }
    if (index?.kind == CockpitTestTemplateValueKind.literal &&
        (index!.value! as int) < 0) {
      throw const FormatException('Locator index must be non-negative.');
    }
    for (final coordinate in <CockpitTestTemplateValue?>[x, y]) {
      if (coordinate?.kind == CockpitTestTemplateValueKind.literal) {
        final value = coordinate!.value! as num;
        if (value < 0 || value > 1) {
          throw const FormatException(
            'Coordinate locator values must be normalized from 0 through 1.',
          );
        }
      }
    }
    if (threshold?.kind == CockpitTestTemplateValueKind.literal) {
      final value = threshold!.value! as num;
      if (value <= 0 || value > 1) {
        throw const FormatException('Visual threshold must be in (0, 1].');
      }
    }
  }
}

final class CockpitTestLocator {
  CockpitTestLocator({
    required this.strategy,
    this.value,
    this.x,
    this.y,
    this.threshold,
    this.index,
    this.ancestor,
    Iterable<CockpitTestLocator> fallbacks = const <CockpitTestLocator>[],
  }) : fallbacks = List<CockpitTestLocator>.unmodifiable(fallbacks) {
    _validate();
  }

  final CockpitTestLocatorStrategy strategy;
  final String? value;
  final double? x;
  final double? y;
  final double? threshold;
  final int? index;
  final CockpitTestLocator? ancestor;
  final List<CockpitTestLocator> fallbacks;

  bool get degraded =>
      strategy == CockpitTestLocatorStrategy.coordinate ||
      strategy == CockpitTestLocatorStrategy.visual;

  Iterable<CockpitTestLocator> get flattened sync* {
    yield this;
    for (final fallback in fallbacks) {
      yield* fallback.flattened;
    }
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'strategy': strategy.name,
    if (value != null) 'value': value,
    if (x != null) 'x': x,
    if (y != null) 'y': y,
    if (threshold != null) 'threshold': threshold,
    if (index != null) 'index': index,
    if (ancestor != null) 'ancestor': ancestor!.toJson(),
    if (fallbacks.isNotEmpty)
      'fallbacks': fallbacks.map((locator) => locator.toJson()).toList(),
  };

  factory CockpitTestLocator.fromJson(Object? value, {required String path}) {
    final template = CockpitTestLocatorTemplate.fromJson(value, path: path);
    Object? literal(CockpitTestTemplateValue? candidate, String field) {
      if (candidate == null) {
        return null;
      }
      if (candidate.kind != CockpitTestTemplateValueKind.literal) {
        throw FormatException('Unbound locator value at $path.$field.');
      }
      return candidate.value;
    }

    return CockpitTestLocator(
      strategy: template.strategy,
      value: literal(template.value, 'value') as String?,
      x: (literal(template.x, 'x') as num?)?.toDouble(),
      y: (literal(template.y, 'y') as num?)?.toDouble(),
      threshold: (literal(template.threshold, 'threshold') as num?)?.toDouble(),
      index: literal(template.index, 'index') as int?,
      ancestor: template.ancestor == null
          ? null
          : CockpitTestLocator.fromJson(
              template.ancestor!.toJson(),
              path: '$path.ancestor',
            ),
      fallbacks: <CockpitTestLocator>[
        for (var index = 0; index < template.fallbacks.length; index += 1)
          CockpitTestLocator.fromJson(
            template.fallbacks[index].toJson(),
            path: '$path.fallbacks[$index]',
          ),
      ],
    );
  }

  void _validate() {
    final semantic =
        strategy != CockpitTestLocatorStrategy.coordinate &&
        strategy != CockpitTestLocatorStrategy.visual;
    if (semantic && (value == null || value!.trim().isEmpty)) {
      throw FormatException('${strategy.name} locator requires value.');
    }
    if (strategy == CockpitTestLocatorStrategy.coordinate) {
      if (x == null || y == null || value != null || threshold != null) {
        throw const FormatException(
          'A coordinate locator requires x/y and forbids value/threshold.',
        );
      }
      if (x! < 0 || x! > 1 || y! < 0 || y! > 1) {
        throw const FormatException(
          'Coordinate locator values must be normalized from 0 through 1.',
        );
      }
    }
    if (strategy == CockpitTestLocatorStrategy.visual) {
      if (value == null || value!.trim().isEmpty || x != null || y != null) {
        throw const FormatException(
          'A visual locator requires value and forbids x/y.',
        );
      }
      if (threshold != null && (threshold! <= 0 || threshold! > 1)) {
        throw const FormatException('Visual threshold must be in (0, 1].');
      }
    }
    if (semantic && (x != null || y != null || threshold != null)) {
      throw FormatException(
        '${strategy.name} locator forbids visual coordinates.',
      );
    }
    if (index != null && index! < 0) {
      throw const FormatException('Locator index must be non-negative.');
    }
  }

  @override
  bool operator ==(Object other) =>
      other is CockpitTestLocator &&
      other.strategy == strategy &&
      other.value == value &&
      other.x == x &&
      other.y == y &&
      other.threshold == threshold &&
      other.index == index &&
      other.ancestor == ancestor &&
      const ListEquality<CockpitTestLocator>().equals(
        other.fallbacks,
        fallbacks,
      );

  @override
  int get hashCode => Object.hash(
    strategy,
    value,
    x,
    y,
    threshold,
    index,
    ancestor,
    const ListEquality<CockpitTestLocator>().hash(fallbacks),
  );
}
