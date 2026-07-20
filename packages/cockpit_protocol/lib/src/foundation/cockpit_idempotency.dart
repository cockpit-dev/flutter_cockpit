import 'cockpit_foundation_value_reader.dart';

final class CockpitIdempotencyKey {
  CockpitIdempotencyKey(this.value) {
    if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9._:-]{0,127}$').hasMatch(value)) {
      throw const FormatException('Invalid idempotency key.');
    }
  }

  final String value;

  factory CockpitIdempotencyKey.fromJson(Object? value, {String path = r'$'}) {
    return CockpitIdempotencyKey(
      CockpitFoundationValueReader.string(value, path, maximum: 128),
    );
  }

  String toJson() => value;

  @override
  bool operator ==(Object other) =>
      other is CockpitIdempotencyKey && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}
