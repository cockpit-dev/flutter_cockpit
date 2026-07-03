import 'package:collection/collection.dart';

final class CockpitNetworkQuery {
  const CockpitNetworkQuery({
    this.method,
    this.uriContains,
    this.onlyFailures = false,
    this.statusCodeAtLeast,
  });

  final String? method;
  final String? uriContains;
  final bool onlyFailures;
  final int? statusCodeAtLeast;

  static const MapEquality<String, Object?> _mapEquality =
      MapEquality<String, Object?>();

  bool get isEmpty =>
      (method == null || method!.isEmpty) &&
      (uriContains == null || uriContains!.isEmpty) &&
      !onlyFailures &&
      statusCodeAtLeast == null;

  Map<String, Object?> toJson() => <String, Object?>{
    if (method != null) 'method': method,
    if (uriContains != null) 'uriContains': uriContains,
    'onlyFailures': onlyFailures,
    if (statusCodeAtLeast != null) 'statusCodeAtLeast': statusCodeAtLeast,
  };

  factory CockpitNetworkQuery.fromJson(Map<String, Object?> json) {
    return CockpitNetworkQuery(
      method: json['method'] as String?,
      uriContains: json['uriContains'] as String?,
      onlyFailures: json['onlyFailures'] as bool? ?? false,
      statusCodeAtLeast: json['statusCodeAtLeast'] as int?,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CockpitNetworkQuery &&
            _mapEquality.equals(other.toJson(), toJson());
  }

  @override
  int get hashCode => _mapEquality.hash(toJson());
}
