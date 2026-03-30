import '../infrastructure/cockpit_file_system.dart';

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

final class CockpitReadWorkspaceGoalsService {
  CockpitReadWorkspaceGoalsService({
    CockpitFileSystem? fileSystem,
  }) : _fileSystem = fileSystem ?? const LocalCockpitFileSystem();

  final CockpitFileSystem _fileSystem;

  Future<CockpitWorkspaceDocument> read({
    String goalsFilePath = 'GOALS.md',
  }) async {
    final file = _fileSystem.file(goalsFilePath);
    final text = await file.readAsString();
    return CockpitWorkspaceDocument(path: file.path, text: text);
  }
}
