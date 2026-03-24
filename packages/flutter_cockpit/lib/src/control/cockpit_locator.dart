import 'package:collection/collection.dart';

enum CockpitLocatorKind {
  cockpitId,
  semanticId,
  key,
  text,
  tooltip,
  type,
  route;

  static CockpitLocatorKind fromJson(Object? json) {
    return values.byName(json! as String);
  }
}

final class CockpitLocator {
  const CockpitLocator({
    required this.kind,
    required this.value,
    this.fallbacks = const [],
  });

  final CockpitLocatorKind kind;
  final String value;
  final List<CockpitLocator> fallbacks;

  static const ListEquality<CockpitLocator> _fallbackListEquality =
      ListEquality<CockpitLocator>();

  Map<String, Object?> toJson() => {
        'kind': kind.name,
        'value': value,
        'fallbacks': fallbacks.map((fallback) => fallback.toJson()).toList(),
      };

  factory CockpitLocator.fromJson(Map<String, Object?> json) {
    final fallbacks = (json['fallbacks'] as List<Object?>? ?? const <Object?>[])
        .cast<Map<Object?, Object?>>()
        .map((item) => CockpitLocator.fromJson(Map<String, Object?>.from(item)))
        .toList(growable: false);

    return CockpitLocator(
      kind: CockpitLocatorKind.fromJson(json['kind']),
      value: json['value']! as String,
      fallbacks: fallbacks,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CockpitLocator &&
            other.kind == kind &&
            other.value == value &&
            _fallbackListEquality.equals(other.fallbacks, fallbacks);
  }

  @override
  int get hashCode =>
      Object.hash(kind, value, _fallbackListEquality.hash(fallbacks));
}
