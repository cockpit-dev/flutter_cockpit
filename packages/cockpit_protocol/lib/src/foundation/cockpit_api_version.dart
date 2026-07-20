import 'cockpit_decode_policy.dart';
import 'cockpit_foundation_value_reader.dart';

final class CockpitApiVersion implements Comparable<CockpitApiVersion> {
  CockpitApiVersion({required this.major, required this.minor}) {
    if (major < 1 || minor < 0) {
      throw const FormatException('API version numbers are invalid.');
    }
  }

  final int major;
  final int minor;

  Map<String, Object?> toJson() => <String, Object?>{
    'major': major,
    'minor': minor,
  };

  factory CockpitApiVersion.fromJson(
    Object? value, {
    String path = r'$',
    CockpitDecodePolicy decodePolicy = CockpitDecodePolicy.requests,
  }) {
    final json = CockpitFoundationValueReader.object(value, path);
    CockpitFoundationValueReader.keys(
      json,
      const <String>{'major', 'minor'},
      path,
      required: const <String>{'major', 'minor'},
      policy: decodePolicy,
    );
    return CockpitApiVersion(
      major: CockpitFoundationValueReader.integer(
        json['major'],
        '$path.major',
        min: 1,
      ),
      minor: CockpitFoundationValueReader.integer(
        json['minor'],
        '$path.minor',
        min: 0,
      ),
    );
  }

  @override
  int compareTo(CockpitApiVersion other) {
    final majorComparison = major.compareTo(other.major);
    return majorComparison == 0
        ? minor.compareTo(other.minor)
        : majorComparison;
  }

  @override
  bool operator ==(Object other) {
    return other is CockpitApiVersion &&
        other.major == major &&
        other.minor == minor;
  }

  @override
  int get hashCode => Object.hash(major, minor);

  @override
  String toString() => '$major.$minor';
}

final class CockpitFeatureDescriptor {
  CockpitFeatureDescriptor({
    required this.id,
    required this.revision,
    required this.minimumApiMinor,
  }) {
    CockpitFoundationValueReader.id(id, r'$.id');
    if (revision < 1 || minimumApiMinor < 0) {
      throw const FormatException('Feature version metadata is invalid.');
    }
  }

  final String id;
  final int revision;
  final int minimumApiMinor;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'revision': revision,
    'minimumApiMinor': minimumApiMinor,
  };

  factory CockpitFeatureDescriptor.fromJson(
    Object? value, {
    String path = r'$',
    CockpitDecodePolicy decodePolicy = CockpitDecodePolicy.requests,
  }) {
    final json = CockpitFoundationValueReader.object(value, path);
    const fields = <String>{'id', 'revision', 'minimumApiMinor'};
    CockpitFoundationValueReader.keys(
      json,
      fields,
      path,
      required: fields,
      policy: decodePolicy,
    );
    return CockpitFeatureDescriptor(
      id: CockpitFoundationValueReader.id(json['id'], '$path.id'),
      revision: CockpitFoundationValueReader.integer(
        json['revision'],
        '$path.revision',
        min: 1,
      ),
      minimumApiMinor: CockpitFoundationValueReader.integer(
        json['minimumApiMinor'],
        '$path.minimumApiMinor',
        min: 0,
      ),
    );
  }
}
