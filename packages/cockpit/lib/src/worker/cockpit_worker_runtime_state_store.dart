import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../foundation/cockpit_ids.dart';
import '../foundation/cockpit_locked_json_store.dart';
import '../foundation/cockpit_permissions.dart';

abstract interface class CockpitWorkerRuntimeStateStore {
  Future<Map<String, Object?>> read();

  Future<void> write(Map<String, Object?> state);
}

final class CockpitInMemoryWorkerRuntimeStateStore
    implements CockpitWorkerRuntimeStateStore {
  Map<String, Object?> _state = const <String, Object?>{};

  @override
  Future<Map<String, Object?>> read() async => _deepCopy(_state);

  @override
  Future<void> write(Map<String, Object?> state) async {
    _state = _deepCopy(state);
  }
}

final class CockpitFileWorkerRuntimeStateStore
    implements CockpitWorkerRuntimeStateStore {
  CockpitFileWorkerRuntimeStateStore({
    required String root,
    required CockpitPermissionHardener permissionHardener,
    required CockpitDirectorySyncer directorySyncer,
    CockpitTokenGenerator? tokenGenerator,
  }) : root = p.normalize(p.absolute(root)),
       _permissionHardener = permissionHardener,
       _directorySyncer = directorySyncer,
       _tokenGenerator = tokenGenerator ?? CockpitSecureTokenGenerator(),
       _manifestStore = CockpitLockedJsonStore<Map<String, Object?>?>(
         path: p.join(p.normalize(p.absolute(root)), 'manifest.json'),
         codec: const _NullableRuntimeManifestCodec(),
         createInitial: () => null,
         permissionHardener: permissionHardener,
         directorySyncer: directorySyncer,
         maximumBytes: maximumManifestBytes,
       );

  static const int maximumManifestBytes = 512 * 1024;
  static const int targetShardBytes = 1024 * 1024;
  static const int maximumRecordBytes = 2 * 1024 * 1024;
  static const int maximumShardBytes = maximumRecordBytes + 64 * 1024;
  static const String manifestSchema = 'cockpit.worker.runtime-manifest/v1';
  static const String metadataSchema = 'cockpit.worker.runtime-metadata/v1';
  static const String shardSchema = 'cockpit.worker.runtime-shard/v1';
  static const Set<String> _collectionFields = <String>{
    'targets',
    'apps',
    'sessions',
    'recordings',
    'artifacts',
    'probes',
  };

  final String root;
  final CockpitPermissionHardener _permissionHardener;
  final CockpitDirectorySyncer _directorySyncer;
  final CockpitTokenGenerator _tokenGenerator;
  final CockpitLockedJsonStore<Map<String, Object?>?> _manifestStore;
  var _generationSequence = 0;

  String get _generationsRoot => p.join(root, 'generations');

  @override
  Future<Map<String, Object?>> read() async {
    await _prepareRoots();
    return _manifestStore.transact<Map<String, Object?>>((raw) async {
      await _scanRoot();
      await _scanGenerationsRoot();
      if (raw == null) {
        await _requireEmptyGenerations();
        return CockpitLockedJsonUpdate.readOnly(raw, const <String, Object?>{});
      }
      final manifest = _decodeManifest(raw);
      final state = await _readGeneration(manifest);
      return CockpitLockedJsonUpdate.readOnly(raw, state);
    });
  }

  @override
  Future<void> write(Map<String, Object?> state) async {
    await _prepareRoots();
    await _manifestStore.transact<void>((currentRaw) async {
      await _scanRoot();
      await _scanGenerationsRoot();
      final current = currentRaw == null ? null : _decodeManifest(currentRaw);
      if (current == null) await _requireEmptyGenerations();
      await _deleteUnreferencedGenerations(current?.generation);
      final generation = _newGeneration();
      final generationDirectory = Directory(
        p.join(_generationsRoot, generation),
      );
      try {
        await generationDirectory.create();
        await _permissionHardener.hardenDirectory(generationDirectory);
        await _directorySyncer.sync(_generationsRoot);
        final manifest = await _writeGeneration(
          generationDirectory,
          generation,
          state,
        );
        return CockpitLockedJsonUpdate.write(manifest.toJson(), null);
      } catch (_) {
        if (await generationDirectory.exists()) {
          await generationDirectory.delete(recursive: true);
          await _directorySyncer.sync(_generationsRoot);
        }
        rethrow;
      }
    });
  }

  Future<void> _prepareRoots() async {
    final rootDirectory = Directory(root);
    await rootDirectory.create(recursive: true);
    await _permissionHardener.hardenDirectory(rootDirectory);
    await _requireCanonicalDirectory(rootDirectory, 'runtime registry root');
    final generations = Directory(_generationsRoot);
    final generationsExisted = await generations.exists();
    await generations.create();
    await _permissionHardener.hardenDirectory(generations);
    await _requireCanonicalDirectory(generations, 'runtime generations root');
    if (!generationsExisted) await _directorySyncer.sync(root);
    await _scanRoot();
  }

  Future<void> _scanRoot() async {
    await for (final entity in Directory(root).list(followLinks: false)) {
      final name = p.basename(entity.path);
      final temporaryTarget = cockpitAtomicJsonTemporaryTargetName(name);
      if (temporaryTarget != null) {
        if (temporaryTarget != 'manifest.json') {
          throw FileSystemException(
            'Worker runtime root contains an unexpected temporary file.',
            entity.path,
          );
        }
        continue;
      }
      if (name == 'generations') {
        await _requireCanonicalDirectory(
          Directory(entity.path),
          'runtime generations root',
        );
        continue;
      }
      if (name == 'manifest.json' || name == 'manifest.json.lock') {
        await cockpitValidateCanonicalRegularFile(
          entity.path,
          diagnostic: 'Worker runtime root file is invalid.',
        );
        continue;
      }
      throw FileSystemException(
        'Worker runtime root contains an unexpected entry.',
        entity.path,
      );
    }
  }

  Future<void> _scanGenerationsRoot() async {
    await for (final entity in Directory(
      _generationsRoot,
    ).list(followLinks: false)) {
      final name = p.basename(entity.path);
      if (!RegExp(r'^generation_[a-f0-9]{32}$').hasMatch(name)) {
        throw FileSystemException(
          'Worker runtime generations root contains an unexpected entry.',
          entity.path,
        );
      }
      await _requireCanonicalDirectory(
        Directory(entity.path),
        'runtime generation',
      );
    }
  }

  Future<void> _requireEmptyGenerations() async {
    await for (final entity in Directory(
      _generationsRoot,
    ).list(followLinks: false)) {
      throw FileSystemException(
        'Worker runtime manifest is missing while generation evidence exists.',
        entity.path,
      );
    }
  }

  Future<_RuntimeManifest> _writeGeneration(
    Directory directory,
    String generation,
    Map<String, Object?> state,
  ) async {
    final stateKeys = state.keys.toSet();
    const expectedKeys = <String>{
      'schemaVersion',
      'workspaceId',
      ..._collectionFields,
    };
    if (stateKeys.length != expectedKeys.length ||
        !stateKeys.containsAll(expectedKeys)) {
      throw const FormatException('Worker runtime state shape is invalid.');
    }
    final metadata = <String, Object?>{
      'schemaVersion': metadataSchema,
      'stateSchemaVersion': state['schemaVersion'],
      'workspaceId': state['workspaceId'],
    };
    final metadataDescriptor = await _writeJson(
      directory,
      name: 'metadata.json',
      value: metadata,
    );
    final shards = <_RuntimeShardDescriptor>[];
    for (final field in _collectionFields) {
      final entries = state[field];
      if (entries is! List<Object?>) {
        throw FormatException('Worker runtime collection $field is invalid.');
      }
      final chunks = _partition(field, entries);
      for (var index = 0; index < chunks.length; index += 1) {
        final name = '$field-${index.toString().padLeft(6, '0')}.json';
        final value = <String, Object?>{
          'schemaVersion': shardSchema,
          'field': field,
          'entries': chunks[index],
        };
        final file = await _writeJson(directory, name: name, value: value);
        shards.add(
          _RuntimeShardDescriptor(
            field: field,
            name: file.name,
            sizeBytes: file.sizeBytes,
            sha256: file.sha256,
          ),
        );
      }
    }
    await _directorySyncer.sync(directory.path);
    await _directorySyncer.sync(_generationsRoot);
    return _RuntimeManifest(
      generation: generation,
      metadata: metadataDescriptor,
      shards: shards,
    );
  }

  List<List<Object?>> _partition(String field, List<Object?> entries) {
    if (entries.isEmpty) return <List<Object?>>[const <Object?>[]];
    final chunks = <List<Object?>>[];
    var current = <Object?>[];
    var estimatedBytes = 96 + field.length;
    for (final entry in entries) {
      final entryBytes = utf8.encode(jsonEncode(entry)).length;
      if (entryBytes > maximumRecordBytes) {
        throw CockpitStorageException(
          code: 'storageTooLarge',
          path: root,
          diagnostic: 'Worker runtime $field entry exceeds record bounds.',
        );
      }
      final nextBytes = estimatedBytes + entryBytes + (current.isEmpty ? 0 : 1);
      if (current.isNotEmpty && nextBytes > targetShardBytes) {
        chunks.add(current);
        current = <Object?>[];
        estimatedBytes = 96 + field.length;
      }
      current.add(entry);
      estimatedBytes += entryBytes + (current.length == 1 ? 0 : 1);
    }
    chunks.add(current);
    return chunks;
  }

  Future<_RuntimeFileDescriptor> _writeJson(
    Directory directory, {
    required String name,
    required Object? value,
  }) async {
    final bytes = utf8.encode('${jsonEncode(value)}\n');
    if (bytes.length > maximumShardBytes) {
      throw CockpitStorageException(
        code: 'storageTooLarge',
        path: p.join(directory.path, name),
        diagnostic: 'Worker runtime shard exceeds $maximumShardBytes bytes.',
      );
    }
    await CockpitAtomicJsonFile(
      permissionHardener: _permissionHardener,
      directorySyncer: _directorySyncer,
    ).write(
      p.join(directory.path, name),
      value,
      maximumBytes: maximumShardBytes,
    );
    return _RuntimeFileDescriptor(
      name: name,
      sizeBytes: bytes.length,
      sha256: sha256.convert(bytes).toString(),
    );
  }

  Future<Map<String, Object?>> _readGeneration(
    _RuntimeManifest manifest,
  ) async {
    final directoryPath = p.join(_generationsRoot, manifest.generation);
    final directory = Directory(directoryPath);
    await _requireCanonicalDirectory(directory, 'runtime generation');
    await _validateGenerationFiles(directory, manifest);
    final metadataJson = await _readJson(directory, manifest.metadata);
    final metadata = metadataJson is Map<String, Object?>
        ? metadataJson
        : throw const FormatException('Worker runtime metadata is invalid.');
    if (metadata.length != 3 ||
        metadata['schemaVersion'] != metadataSchema ||
        metadata['stateSchemaVersion'] is! String ||
        metadata['workspaceId'] is! String) {
      throw const FormatException('Worker runtime metadata is invalid.');
    }
    final collections = <String, List<Object?>>{
      for (final field in _collectionFields) field: <Object?>[],
    };
    for (final shard in manifest.shards) {
      final json = await _readJson(
        directory,
        _RuntimeFileDescriptor(
          name: shard.name,
          sizeBytes: shard.sizeBytes,
          sha256: shard.sha256,
        ),
      );
      if (json is! Map<String, Object?> ||
          json.length != 3 ||
          json['schemaVersion'] != shardSchema ||
          json['field'] != shard.field ||
          json['entries'] is! List<Object?>) {
        throw FormatException('Worker runtime shard ${shard.name} is invalid.');
      }
      collections[shard.field]!.addAll(json['entries']! as List<Object?>);
    }
    return <String, Object?>{
      'schemaVersion': metadata['stateSchemaVersion'],
      'workspaceId': metadata['workspaceId'],
      for (final entry in collections.entries) entry.key: entry.value,
    };
  }

  Future<Object?> _readJson(
    Directory directory,
    _RuntimeFileDescriptor descriptor,
  ) async {
    final path = p.join(directory.path, descriptor.name);
    if (p.basename(path) != descriptor.name) {
      throw const FormatException('Worker runtime shard name is invalid.');
    }
    await cockpitValidateCanonicalRegularFile(
      path,
      diagnostic: 'Worker runtime generation file is invalid.',
    );
    final file = File(path);
    final length = await file.length();
    if (length != descriptor.sizeBytes || length > maximumShardBytes) {
      throw const FormatException('Worker runtime generation size mismatch.');
    }
    final bytes = await file.readAsBytes();
    if (bytes.length != length ||
        sha256.convert(bytes).toString() != descriptor.sha256) {
      throw const FormatException(
        'Worker runtime generation integrity mismatch.',
      );
    }
    return jsonDecode(utf8.decode(bytes, allowMalformed: false));
  }

  Future<void> _validateGenerationFiles(
    Directory directory,
    _RuntimeManifest manifest,
  ) async {
    final expected = <String>{
      manifest.metadata.name,
      for (final shard in manifest.shards) shard.name,
    };
    await for (final entity in directory.list(followLinks: false)) {
      final name = p.basename(entity.path);
      if (!expected.remove(name)) {
        throw FileSystemException(
          'Worker runtime generation contains an unexpected entry.',
          entity.path,
        );
      }
      await cockpitValidateCanonicalRegularFile(
        entity.path,
        diagnostic: 'Worker runtime generation entry is invalid.',
      );
      if (!p.isWithin(directory.path, p.normalize(entity.path))) {
        throw FileSystemException(
          'Worker runtime generation entry is not confined.',
          entity.path,
        );
      }
    }
    if (expected.isNotEmpty) {
      throw FileSystemException(
        'Worker runtime generation is incomplete.',
        directory.path,
      );
    }
  }

  _RuntimeManifest _decodeManifest(Map<String, Object?> json) {
    if (json.length != 4 ||
        json['schemaVersion'] != manifestSchema ||
        json['generation'] is! String ||
        json['metadata'] is! Map<String, Object?> ||
        json['shards'] is! List<Object?>) {
      throw const FormatException('Worker runtime manifest is invalid.');
    }
    final generation = json['generation']! as String;
    if (!RegExp(r'^generation_[a-f0-9]{32}$').hasMatch(generation)) {
      throw const FormatException('Worker runtime generation id is invalid.');
    }
    final metadata = _decodeFileDescriptor(
      json['metadata']! as Map<String, Object?>,
      expectedName: 'metadata.json',
    );
    final shards = <_RuntimeShardDescriptor>[];
    final seenNames = <String>{};
    final seenFields = <String>{};
    final nextIndex = <String, int>{};
    for (final value in json['shards']! as List<Object?>) {
      if (value is! Map<String, Object?> || value['field'] is! String) {
        throw const FormatException('Worker runtime shard descriptor invalid.');
      }
      final field = value['field']! as String;
      if (!_collectionFields.contains(field)) {
        throw const FormatException('Worker runtime shard field is invalid.');
      }
      final descriptor = _decodeFileDescriptor(value);
      final index = nextIndex[field] ?? 0;
      final expectedName = '$field-${index.toString().padLeft(6, '0')}.json';
      if (descriptor.name != expectedName || !seenNames.add(descriptor.name)) {
        throw const FormatException('Worker runtime shard name is invalid.');
      }
      nextIndex[field] = index + 1;
      seenFields.add(field);
      shards.add(
        _RuntimeShardDescriptor(
          field: field,
          name: descriptor.name,
          sizeBytes: descriptor.sizeBytes,
          sha256: descriptor.sha256,
        ),
      );
    }
    if (!seenFields.containsAll(_collectionFields)) {
      throw const FormatException('Worker runtime manifest is incomplete.');
    }
    return _RuntimeManifest(
      generation: generation,
      metadata: metadata,
      shards: shards,
    );
  }

  _RuntimeFileDescriptor _decodeFileDescriptor(
    Map<String, Object?> json, {
    String? expectedName,
  }) {
    const requiredKeys = <String>{'name', 'sizeBytes', 'sha256'};
    final allowedKeys = expectedName == null
        ? const <String>{'field', ...requiredKeys}
        : requiredKeys;
    if (json.keys.toSet().difference(allowedKeys).isNotEmpty ||
        !json.keys.toSet().containsAll(requiredKeys) ||
        json['name'] is! String ||
        json['sizeBytes'] is! int ||
        json['sha256'] is! String) {
      throw const FormatException('Worker runtime file descriptor invalid.');
    }
    final name = json['name']! as String;
    final sizeBytes = json['sizeBytes']! as int;
    final digest = json['sha256']! as String;
    if ((expectedName != null && name != expectedName) ||
        p.basename(name) != name ||
        sizeBytes < 1 ||
        sizeBytes > maximumShardBytes ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(digest)) {
      throw const FormatException('Worker runtime file descriptor invalid.');
    }
    return _RuntimeFileDescriptor(
      name: name,
      sizeBytes: sizeBytes,
      sha256: digest,
    );
  }

  Future<void> _deleteUnreferencedGenerations(String? retained) async {
    await for (final entity in Directory(
      _generationsRoot,
    ).list(followLinks: false)) {
      final name = p.basename(entity.path);
      if (!RegExp(r'^generation_[a-f0-9]{32}$').hasMatch(name)) {
        throw FileSystemException(
          'Worker runtime generations root contains an unexpected entry.',
          entity.path,
        );
      }
      final type = await FileSystemEntity.type(entity.path, followLinks: false);
      if (type != FileSystemEntityType.directory) {
        throw FileSystemException(
          'Worker runtime generation entry is invalid.',
          entity.path,
        );
      }
      await _requireCanonicalDirectory(
        Directory(entity.path),
        'runtime generation',
      );
      if (name == retained) continue;
      await Directory(entity.path).delete(recursive: true);
      await _directorySyncer.sync(_generationsRoot);
    }
  }

  Future<void> _requireCanonicalDirectory(
    Directory directory,
    String kind,
  ) async {
    final type = await FileSystemEntity.type(
      directory.path,
      followLinks: false,
    );
    if (type != FileSystemEntityType.directory ||
        !p.equals(
          p.normalize(await directory.resolveSymbolicLinks()),
          p.normalize(directory.path),
        )) {
      throw FileSystemException(
        'Worker $kind is not canonical.',
        directory.path,
      );
    }
  }

  String _newGeneration() {
    _generationSequence += 1;
    final source =
        '${_tokenGenerator.nextToken(byteLength: 24)}:$pid:'
        '${DateTime.now().toUtc().microsecondsSinceEpoch}:$_generationSequence';
    return 'generation_${sha256.convert(utf8.encode(source)).toString().substring(0, 32)}';
  }
}

final class _NullableRuntimeManifestCodec
    implements CockpitJsonCodec<Map<String, Object?>?> {
  const _NullableRuntimeManifestCodec();

  @override
  Map<String, Object?>? decode(Object? json) => json == null
      ? null
      : Map<String, Object?>.from(json as Map<Object?, Object?>);

  @override
  Object? encode(Map<String, Object?>? value) => value;
}

final class _RuntimeManifest {
  const _RuntimeManifest({
    required this.generation,
    required this.metadata,
    required this.shards,
  });

  final String generation;
  final _RuntimeFileDescriptor metadata;
  final List<_RuntimeShardDescriptor> shards;

  Map<String, Object?> toJson() => <String, Object?>{
    'schemaVersion': CockpitFileWorkerRuntimeStateStore.manifestSchema,
    'generation': generation,
    'metadata': metadata.toJson(),
    'shards': shards.map((shard) => shard.toJson()).toList(growable: false),
  };
}

class _RuntimeFileDescriptor {
  const _RuntimeFileDescriptor({
    required this.name,
    required this.sizeBytes,
    required this.sha256,
  });

  final String name;
  final int sizeBytes;
  final String sha256;

  Map<String, Object?> toJson() => <String, Object?>{
    'name': name,
    'sizeBytes': sizeBytes,
    'sha256': sha256,
  };
}

final class _RuntimeShardDescriptor extends _RuntimeFileDescriptor {
  const _RuntimeShardDescriptor({
    required this.field,
    required super.name,
    required super.sizeBytes,
    required super.sha256,
  });

  final String field;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'field': field,
    ...super.toJson(),
  };
}

Map<String, Object?> _deepCopy(Map<String, Object?> value) =>
    Map<String, Object?>.from(jsonDecode(jsonEncode(value))! as Map);
