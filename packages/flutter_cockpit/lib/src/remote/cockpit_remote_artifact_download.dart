import '../model/cockpit_artifact_ref.dart';

final class CockpitRemoteArtifactDownload {
  const CockpitRemoteArtifactDownload({
    required this.artifact,
    required this.downloadPath,
  });

  final CockpitArtifactRef artifact;
  final String downloadPath;

  Map<String, Object?> toJson() => <String, Object?>{
    'artifact': artifact.toJson(),
    'downloadPath': downloadPath,
  };

  factory CockpitRemoteArtifactDownload.fromJson(Map<String, Object?> json) {
    final artifactJson = json['artifact'] as Map<Object?, Object?>;
    return CockpitRemoteArtifactDownload(
      artifact: CockpitArtifactRef.fromJson(
        Map<String, Object?>.from(artifactJson),
      ),
      downloadPath: json['downloadPath']! as String,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CockpitRemoteArtifactDownload &&
            other.artifact == artifact &&
            other.downloadPath == downloadPath;
  }

  @override
  int get hashCode => Object.hash(artifact, downloadPath);
}
