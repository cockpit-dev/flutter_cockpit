import 'package:collection/collection.dart';

import 'cockpit_locator.dart';

final class CockpitLocatorResolution {
  const CockpitLocatorResolution({
    required this.matchedKind,
    required this.matchedValue,
    this.matchedSignals = const <String, String>{},
  });

  final CockpitLocatorKind matchedKind;
  final String matchedValue;
  final Map<String, String> matchedSignals;

  Map<String, Object?> toJson() => <String, Object?>{
    'matchedKind': matchedKind.name,
    'matchedValue': matchedValue,
    if (matchedSignals.isNotEmpty) 'matchedSignals': matchedSignals,
  };

  factory CockpitLocatorResolution.fromJson(Map<String, Object?> json) {
    final matchedSignalsJson = json['matchedSignals'] as Map<Object?, Object?>?;
    return CockpitLocatorResolution(
      matchedKind: CockpitLocatorKind.fromJson(json['matchedKind']),
      matchedValue: json['matchedValue']! as String,
      matchedSignals: matchedSignalsJson == null
          ? const <String, String>{}
          : Map<String, String>.from(
              matchedSignalsJson.map(
                (key, value) => MapEntry('$key', '$value'),
              ),
            ),
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CockpitLocatorResolution &&
            other.matchedKind == matchedKind &&
            other.matchedValue == matchedValue &&
            const MapEquality<String, String>().equals(
              other.matchedSignals,
              matchedSignals,
            );
  }

  @override
  int get hashCode => Object.hash(
    matchedKind,
    matchedValue,
    const MapEquality<String, String>().hash(matchedSignals),
  );
}
