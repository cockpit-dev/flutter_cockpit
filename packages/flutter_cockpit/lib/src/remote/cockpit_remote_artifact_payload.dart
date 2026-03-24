import 'dart:convert';

import '../model/cockpit_artifact_ref.dart';

final class CockpitRemoteArtifactPayload {
  const CockpitRemoteArtifactPayload({
    required this.artifact,
    required this.bytes,
  });

  final CockpitArtifactRef artifact;
  final List<int> bytes;

  Map<String, Object?> toJson() => <String, Object?>{
        'artifact': artifact.toJson(),
        'bytesBase64': base64Encode(bytes),
      };

  factory CockpitRemoteArtifactPayload.fromJson(Map<String, Object?> json) {
    final artifactJson = json['artifact'] as Map<Object?, Object?>;
    return CockpitRemoteArtifactPayload(
      artifact: CockpitArtifactRef.fromJson(
        Map<String, Object?>.from(artifactJson),
      ),
      bytes: base64Decode(json['bytesBase64']! as String),
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CockpitRemoteArtifactPayload &&
            other.artifact == artifact &&
            _listEquals(other.bytes, bytes);
  }

  @override
  int get hashCode => Object.hash(artifact, Object.hashAll(bytes));

  static bool _listEquals(List<int> left, List<int> right) {
    if (left.length != right.length) {
      return false;
    }
    for (var index = 0; index < left.length; index += 1) {
      if (left[index] != right[index]) {
        return false;
      }
    }
    return true;
  }
}
