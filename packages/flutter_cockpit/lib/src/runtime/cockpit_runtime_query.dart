import 'package:collection/collection.dart';

final class CockpitRuntimeQuery {
  const CockpitRuntimeQuery({this.onlyErrors = false, this.messageContains});

  final bool onlyErrors;
  final String? messageContains;

  static const MapEquality<String, Object?> _mapEquality =
      MapEquality<String, Object?>();

  bool get isEmpty =>
      !onlyErrors &&
      (messageContains == null || messageContains!.trim().isEmpty);

  Map<String, Object?> toJson() => <String, Object?>{
    'onlyErrors': onlyErrors,
    if (messageContains != null) 'messageContains': messageContains,
  };

  factory CockpitRuntimeQuery.fromJson(Map<String, Object?> json) {
    return CockpitRuntimeQuery(
      onlyErrors: json['onlyErrors'] as bool? ?? false,
      messageContains: json['messageContains'] as String?,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CockpitRuntimeQuery &&
            _mapEquality.equals(other.toJson(), toJson());
  }

  @override
  int get hashCode => _mapEquality.hash(toJson());
}
