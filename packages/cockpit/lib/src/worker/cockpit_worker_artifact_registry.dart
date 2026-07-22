final class CockpitWorkerArtifactBinding {
  const CockpitWorkerArtifactBinding({
    required this.artifactId,
    required this.ownerKind,
    required this.ownerId,
    required this.kind,
    required this.name,
    required this.mediaType,
    required this.retainedPath,
    required this.createdAt,
  });

  final String artifactId;
  final String ownerKind;
  final String ownerId;
  final String kind;
  final String name;
  final String mediaType;
  final String retainedPath;
  final DateTime createdAt;

  Map<String, Object?> toReferenceJson() => <String, Object?>{
    'artifactId': artifactId,
    'kind': kind,
    'name': name,
    'mediaType': mediaType,
  };
}

abstract interface class CockpitWorkerArtifactRegistry {
  Future<CockpitWorkerArtifactBinding> registerArtifact({
    required String ownerKind,
    required String ownerId,
    required String kind,
    required String name,
    required String mediaType,
    required String retainedPath,
  });

  Future<CockpitWorkerArtifactBinding> requireArtifact(String artifactId);
}
