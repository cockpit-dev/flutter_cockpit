import 'package:file/file.dart';
import 'package:file/local.dart';

abstract interface class CockpitFileSystem {
  File file(String path);

  Directory directory(String path);

  Link link(String path);

  Future<Directory> systemTemp(String prefix);
}

final class LocalCockpitFileSystem implements CockpitFileSystem {
  const LocalCockpitFileSystem({
    FileSystem fileSystem = const LocalFileSystem(),
  }) : _fileSystem = fileSystem;

  final FileSystem _fileSystem;

  @override
  Directory directory(String path) => _fileSystem.directory(path);

  @override
  File file(String path) => _fileSystem.file(path);

  @override
  Link link(String path) => _fileSystem.link(path);

  @override
  Future<Directory> systemTemp(String prefix) {
    return _fileSystem.systemTempDirectory.createTemp(prefix);
  }
}
