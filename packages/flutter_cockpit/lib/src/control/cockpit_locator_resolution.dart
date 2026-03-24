import 'cockpit_locator.dart';

final class CockpitLocatorResolution {
  const CockpitLocatorResolution({
    required this.matchedKind,
    required this.matchedValue,
  });

  final CockpitLocatorKind matchedKind;
  final String matchedValue;

  Map<String, Object?> toJson() => {
        'matchedKind': matchedKind.name,
        'matchedValue': matchedValue,
      };

  factory CockpitLocatorResolution.fromJson(Map<String, Object?> json) {
    return CockpitLocatorResolution(
      matchedKind: CockpitLocatorKind.fromJson(json['matchedKind']),
      matchedValue: json['matchedValue']! as String,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CockpitLocatorResolution &&
            other.matchedKind == matchedKind &&
            other.matchedValue == matchedValue;
  }

  @override
  int get hashCode => Object.hash(matchedKind, matchedValue);
}
