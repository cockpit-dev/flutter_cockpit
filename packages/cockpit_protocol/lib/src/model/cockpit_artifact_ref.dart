final class CockpitArtifactRef {
  const CockpitArtifactRef({required this.role, required this.relativePath});

  final String role;
  final String relativePath;

  Map<String, Object?> toJson() => {'role': role, 'relativePath': relativePath};

  factory CockpitArtifactRef.fromJson(Map<String, Object?> json) {
    return CockpitArtifactRef(
      role: json['role']! as String,
      relativePath: json['relativePath']! as String,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CockpitArtifactRef &&
            other.role == role &&
            other.relativePath == relativePath;
  }

  @override
  int get hashCode => Object.hash(role, relativePath);
}
