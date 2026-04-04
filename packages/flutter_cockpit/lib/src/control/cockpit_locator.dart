import 'package:collection/collection.dart';

enum CockpitLocatorKind {
  cockpitId,
  semanticId,
  key,
  text,
  tooltip,
  type,
  route,
  registrationId,
  path;

  static CockpitLocatorKind fromJson(Object? json) {
    return values.byName(json! as String);
  }
}

typedef CockpitLocatorSignal = ({CockpitLocatorKind kind, String value});

final class CockpitLocator {
  const CockpitLocator({
    this.cockpitId,
    this.semanticId,
    this.key,
    this.text,
    this.tooltip,
    this.type,
    this.route,
    this.registrationId,
    this.path,
    this.index,
    this.ancestor,
    this.fallbacks = const [],
  });

  final String? cockpitId;
  final String? semanticId;
  final String? key;
  final String? text;
  final String? tooltip;
  final String? type;
  final String? route;
  final String? registrationId;
  final String? path;
  final int? index;
  final CockpitLocator? ancestor;
  final List<CockpitLocator> fallbacks;

  static const ListEquality<CockpitLocator> _fallbackListEquality =
      ListEquality<CockpitLocator>();

  CockpitLocatorKind get kind {
    final primary = primarySignal;
    if (primary != null) {
      return primary.kind;
    }
    throw StateError('CockpitLocator does not define a primary signal.');
  }

  String get value {
    final primary = primarySignal;
    if (primary != null) {
      return primary.value;
    }
    throw StateError('CockpitLocator does not define a primary signal.');
  }

  CockpitLocatorSignal? get primarySignal {
    for (final signal in signals) {
      return signal;
    }
    return null;
  }

  bool get hasSignals => signals.isNotEmpty || ancestor != null;

  Iterable<CockpitLocatorSignal> get signals sync* {
    final emittedKinds = <CockpitLocatorKind>{};
    Iterable<CockpitLocatorSignal> emit(
      CockpitLocatorKind kind,
      String? candidate,
    ) sync* {
      final normalized = _normalizeSignal(candidate);
      if (normalized == null || !emittedKinds.add(kind)) {
        return;
      }
      yield (kind: kind, value: normalized);
    }

    yield* emit(CockpitLocatorKind.cockpitId, cockpitId);
    yield* emit(CockpitLocatorKind.semanticId, semanticId);
    yield* emit(CockpitLocatorKind.key, key);
    yield* emit(CockpitLocatorKind.text, text);
    yield* emit(CockpitLocatorKind.tooltip, tooltip);
    yield* emit(CockpitLocatorKind.type, type);
    yield* emit(CockpitLocatorKind.route, route);
    yield* emit(CockpitLocatorKind.registrationId, registrationId);
    yield* emit(CockpitLocatorKind.path, path);
  }

  Map<String, String> get signalMap {
    final map = <String, String>{};
    for (final signal in signals) {
      map[signal.kind.name] = signal.value;
    }
    return Map<String, String>.unmodifiable(map);
  }

  Map<String, Object?> toJson() {
    final signals = signalMap;
    return <String, Object?>{
      if (signals[CockpitLocatorKind.cockpitId.name] case final value?)
        'cockpitId': value,
      if (signals[CockpitLocatorKind.semanticId.name] case final value?)
        'semanticId': value,
      if (signals[CockpitLocatorKind.key.name] case final value?) 'key': value,
      if (signals[CockpitLocatorKind.text.name] case final value?)
        'text': value,
      if (signals[CockpitLocatorKind.tooltip.name] case final value?)
        'tooltip': value,
      if (signals[CockpitLocatorKind.type.name] case final value?)
        'type': value,
      if (signals[CockpitLocatorKind.route.name] case final value?)
        'route': value,
      if (signals[CockpitLocatorKind.registrationId.name] case final value?)
        'registrationId': value,
      if (signals[CockpitLocatorKind.path.name] case final value?)
        'path': value,
      if (index != null) 'index': index,
      if (ancestor != null) 'ancestor': ancestor!.toJson(),
      'fallbacks': fallbacks.map((fallback) => fallback.toJson()).toList(),
    };
  }

  factory CockpitLocator.fromJson(Map<String, Object?> json) {
    if (json.containsKey('kind') || json.containsKey('value')) {
      throw const FormatException(
        'CockpitLocator JSON no longer supports legacy kind/value fields.',
      );
    }
    final fallbacks = (json['fallbacks'] as List<Object?>? ?? const <Object?>[])
        .cast<Map<Object?, Object?>>()
        .map((item) => CockpitLocator.fromJson(Map<String, Object?>.from(item)))
        .toList(growable: false);
    final ancestorJson = json['ancestor'] as Map<Object?, Object?>?;

    return CockpitLocator(
      cockpitId: json['cockpitId'] as String?,
      semanticId: json['semanticId'] as String?,
      key: json['key'] as String?,
      text: json['text'] as String?,
      tooltip: json['tooltip'] as String?,
      type: json['type'] as String?,
      route: json['route'] as String?,
      registrationId: json['registrationId'] as String?,
      path: json['path'] as String?,
      index: (json['index'] as num?)?.toInt(),
      ancestor: ancestorJson == null
          ? null
          : CockpitLocator.fromJson(Map<String, Object?>.from(ancestorJson)),
      fallbacks: fallbacks,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CockpitLocator &&
            const MapEquality<String, String>().equals(
              other.signalMap,
              signalMap,
            ) &&
            other.index == index &&
            other.ancestor == ancestor &&
            _fallbackListEquality.equals(other.fallbacks, fallbacks);
  }

  @override
  int get hashCode => Object.hash(
        const MapEquality<String, String>().hash(signalMap),
        index,
        ancestor,
        _fallbackListEquality.hash(fallbacks),
      );

  static String? _normalizeSignal(String? value) {
    if (value == null) {
      return null;
    }
    final normalized = value.trim();
    return normalized.isEmpty ? null : normalized;
  }
}
