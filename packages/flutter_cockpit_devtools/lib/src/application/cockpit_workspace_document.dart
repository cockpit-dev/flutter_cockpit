final class CockpitWorkspaceDocument {
  const CockpitWorkspaceDocument({
    required this.path,
    required this.text,
  });

  final String path;
  final String text;

  Map<String, Object?> toJson() => <String, Object?>{
        'path': path,
        'text': text,
      };
}
