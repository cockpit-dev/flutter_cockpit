import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../foundation/cockpit_ids.dart';
import '../foundation/cockpit_locked_json_store.dart';
import '../foundation/cockpit_permissions.dart';
import 'cockpit_worker_value_reader.dart';

final class CockpitWorkerRetainedBundle {
  const CockpitWorkerRetainedBundle._({
    required this.path,
    required this.newlyCreated,
  });

  final String path;
  final bool newlyCreated;
}

final class CockpitWorkerCommittedBundlePlan {
  const CockpitWorkerCommittedBundlePlan._({
    required this.sourcePath,
    required this.retainedPath,
    required Object retainerIdentity,
    required String stateRoot,
    required String ownerKind,
    required String ownerId,
    required bool newlyCreated,
    required List<_CommittedBundleEntry> entries,
  }) : _retainerIdentity = retainerIdentity,
       _stateRoot = stateRoot,
       _ownerKind = ownerKind,
       _ownerId = ownerId,
       _newlyCreated = newlyCreated,
       _entries = entries;

  final String sourcePath;
  final String retainedPath;
  final Object _retainerIdentity;
  final String _stateRoot;
  final String _ownerKind;
  final String _ownerId;
  final bool _newlyCreated;
  final List<_CommittedBundleEntry> _entries;
}

final class CockpitWorkerArtifactRetainer {
  CockpitWorkerArtifactRetainer({
    required String stateRoot,
    required String producerRoot,
    required CockpitPermissionHardener permissionHardener,
    required CockpitDirectorySyncer directorySyncer,
    CockpitTokenGenerator? tokenGenerator,
  }) : stateRoot = p.normalize(stateRoot),
       producerRoot = p.normalize(producerRoot),
       _permissionHardener = permissionHardener,
       _directorySyncer = directorySyncer,
       _tokenGenerator = tokenGenerator ?? CockpitSecureTokenGenerator() {
    if (!p.isAbsolute(stateRoot) || p.normalize(stateRoot) != stateRoot) {
      throw const FormatException(
        'Worker artifact state root must be absolute and normalized.',
      );
    }
    if (!p.isAbsolute(producerRoot) ||
        p.normalize(producerRoot) != producerRoot ||
        !p.isWithin(stateRoot, producerRoot)) {
      throw const FormatException(
        'Worker artifact producer root must be confined by state root.',
      );
    }
  }

  final String stateRoot;
  final String producerRoot;
  final CockpitPermissionHardener _permissionHardener;
  final CockpitDirectorySyncer _directorySyncer;
  final CockpitTokenGenerator _tokenGenerator;
  final Object _identity = Object();
  final Map<String, String> _committedCopies = <String, String>{};

  Future<String> retain({
    required String ownerKind,
    required String ownerId,
    required String sourcePath,
    required bool allowDirectory,
    String? committedRoot,
  }) async {
    workerId(ownerId, r'$.ownerId');
    if (!const <String>{'run', 'session', 'recording'}.contains(ownerKind)) {
      throw const FormatException('Artifact owner kind is invalid.');
    }
    if (!p.isAbsolute(sourcePath)) {
      throw const FormatException('Artifact source path must be absolute.');
    }
    final root = await _canonicalStateRoot();
    final normalizedSource = p.normalize(sourcePath);
    if (allowDirectory) {
      if (committedRoot == null) {
        throw const FormatException(
          'A bundle directory requires an explicit committed root capability.',
        );
      }
      final canonicalCommittedRoot = await _canonicalCommittedRoot(
        committedRoot,
        stateRoot: root,
      );
      _validateCommittedRunAuthority(
        canonicalCommittedRoot,
        stateRoot: root,
        ownerKind: ownerKind,
        ownerId: ownerId,
      );
      if (!p.equals(canonicalCommittedRoot, normalizedSource)) {
        throw const FileSystemException(
          'Bundle directory does not match its committed run authority.',
        );
      }
      await _validateInStateSource(
        normalizedSource,
        root: canonicalCommittedRoot,
        allowDirectory: true,
      );
      final plan = await _planCommittedBundle(
        canonicalCommittedRoot,
        stateRoot: root,
        ownerKind: ownerKind,
        ownerId: ownerId,
      );
      return (await commitCommittedBundle(plan)).path;
    }
    if (committedRoot != null) {
      final canonicalCommittedRoot = await _canonicalCommittedRoot(
        committedRoot,
        stateRoot: root,
      );
      _validateCommittedRunAuthority(
        canonicalCommittedRoot,
        stateRoot: root,
        ownerKind: ownerKind,
        ownerId: ownerId,
      );
      if (!p.isWithin(canonicalCommittedRoot, normalizedSource)) {
        throw const FileSystemException(
          'Committed artifact file escapes its bundle root.',
        );
      }
      await _validateInStateSource(
        normalizedSource,
        root: canonicalCommittedRoot,
        allowDirectory: false,
      );
      final plan = await _planCommittedBundle(
        canonicalCommittedRoot,
        stateRoot: root,
        ownerKind: ownerKind,
        ownerId: ownerId,
      );
      final retainedRoot = (await commitCommittedBundle(plan)).path;
      final relative = p.relative(
        normalizedSource,
        from: canonicalCommittedRoot,
      );
      final retainedPath = p.normalize(p.join(retainedRoot, relative));
      if (!p.isWithin(retainedRoot, retainedPath) ||
          await FileSystemEntity.type(retainedPath, followLinks: false) !=
              FileSystemEntityType.file) {
        throw const FileSystemException(
          'Retained bundle artifact is unavailable.',
        );
      }
      return retainedPath;
    }
    final canonicalProducerRoot = await _canonicalProducerRoot(root);
    return _copyProducerFile(
      normalizedSource,
      root: root,
      producerRoot: canonicalProducerRoot,
      ownerKind: ownerKind,
      ownerId: ownerId,
    );
  }

  Future<CockpitWorkerCommittedBundlePlan> planCommittedBundle({
    required String ownerId,
    required String sourcePath,
  }) async {
    workerId(ownerId, r'$.ownerId');
    if (!p.isAbsolute(sourcePath)) {
      throw const FormatException('Artifact source path must be absolute.');
    }
    final root = await _canonicalStateRoot();
    final canonicalCommittedRoot = await _canonicalCommittedRoot(
      sourcePath,
      stateRoot: root,
    );
    _validateCommittedRunAuthority(
      canonicalCommittedRoot,
      stateRoot: root,
      ownerKind: 'run',
      ownerId: ownerId,
    );
    await _validateInStateSource(
      canonicalCommittedRoot,
      root: canonicalCommittedRoot,
      allowDirectory: true,
    );
    return _planCommittedBundle(
      canonicalCommittedRoot,
      stateRoot: root,
      ownerKind: 'run',
      ownerId: ownerId,
    );
  }

  Future<CockpitWorkerRetainedBundle> commitCommittedBundle(
    CockpitWorkerCommittedBundlePlan plan,
  ) async {
    if (!identical(plan._retainerIdentity, _identity)) {
      throw StateError('Committed bundle plan belongs to another retainer.');
    }
    final root = await _canonicalStateRoot();
    if (!p.equals(root, plan._stateRoot)) {
      throw StateError('Committed bundle plan state authority is stale.');
    }
    final sourceRoot = await _canonicalCommittedRoot(
      plan.sourcePath,
      stateRoot: root,
    );
    _validateCommittedRunAuthority(
      sourceRoot,
      stateRoot: root,
      ownerKind: plan._ownerKind,
      ownerId: plan._ownerId,
    );
    final currentSource = await _snapshotDirectory(sourceRoot);
    if (!_sameDirectorySnapshot(plan._entries, currentSource)) {
      throw const FileSystemException(
        'Committed bundle changed after publication preflight.',
      );
    }
    final ownerRoot = _retainedOwnerRoot(
      root,
      ownerKind: plan._ownerKind,
      ownerId: plan._ownerId,
    );
    _validatePlannedRetainedPath(plan.retainedPath, ownerRoot: ownerRoot);
    if (!plan._newlyCreated) {
      if (_committedCopies[sourceRoot] != plan.retainedPath) {
        throw StateError('Committed bundle plan identity is stale.');
      }
      await _validateInStateSource(
        plan.retainedPath,
        root: ownerRoot,
        allowDirectory: true,
      );
      final retained = await _snapshotDirectory(plan.retainedPath);
      if (!_sameDirectorySnapshot(plan._entries, retained)) {
        throw const FileSystemException(
          'Previously retained bundle does not match its source plan.',
        );
      }
      return CockpitWorkerRetainedBundle._(
        path: plan.retainedPath,
        newlyCreated: false,
      );
    }
    if (_committedCopies.containsKey(sourceRoot)) {
      throw StateError('Committed bundle plan was superseded.');
    }
    final parent = await _retainedOwnerDirectory(
      root,
      ownerKind: plan._ownerKind,
      ownerId: plan._ownerId,
    );
    if (!p.equals(parent.path, ownerRoot) ||
        !p.equals(p.dirname(plan.retainedPath), parent.path)) {
      throw StateError('Committed bundle plan target authority is stale.');
    }
    final target = Directory(plan.retainedPath);
    final staging = Directory('${plan.retainedPath}.tmp');
    if (await FileSystemEntity.type(target.path, followLinks: false) !=
            FileSystemEntityType.notFound ||
        await FileSystemEntity.type(staging.path, followLinks: false) !=
            FileSystemEntityType.notFound) {
      throw FileSystemException(
        'Committed bundle plan target already exists.',
        target.path,
      );
    }
    var renamed = false;
    try {
      await staging.create();
      await _permissionHardener.hardenDirectory(staging);
      for (final entry in plan._entries.where((entry) => entry.directory)) {
        final directory = await Directory(
          p.join(staging.path, entry.relativePath),
        ).create(recursive: true);
        await _permissionHardener.hardenDirectory(directory);
        await _directorySyncer.sync(directory.parent.path);
      }
      for (final entry in plan._entries.where((entry) => !entry.directory)) {
        await _copyVerifiedFile(
          File(p.join(sourceRoot, entry.relativePath)),
          File(p.join(staging.path, entry.relativePath)),
          expected: entry,
        );
      }
      final after = await _snapshotDirectory(sourceRoot);
      if (!_sameDirectorySnapshot(plan._entries, after)) {
        throw const FileSystemException(
          'Committed bundle changed while being retained.',
        );
      }
      final staged = await _snapshotDirectory(staging.path);
      if (!_sameDirectorySnapshot(plan._entries, staged)) {
        throw const FileSystemException(
          'Retained bundle does not match its publication plan.',
        );
      }
      for (final entry in plan._entries.reversed.where(
        (entry) => entry.directory,
      )) {
        await _directorySyncer.sync(p.join(staging.path, entry.relativePath));
      }
      await _directorySyncer.sync(staging.path);
      await staging.rename(target.path);
      renamed = true;
      await _directorySyncer.sync(parent.path);
      await _validateInStateSource(
        target.path,
        root: parent.path,
        allowDirectory: true,
      );
      final retained = await _snapshotDirectory(target.path);
      if (!_sameDirectorySnapshot(plan._entries, retained)) {
        throw const FileSystemException(
          'Committed retained bundle failed post-rename verification.',
        );
      }
      _committedCopies[sourceRoot] = target.path;
      return CockpitWorkerRetainedBundle._(
        path: target.path,
        newlyCreated: true,
      );
    } catch (_) {
      if (await staging.exists()) await staging.delete(recursive: true);
      if (renamed && await target.exists()) {
        await target.delete(recursive: true);
      }
      rethrow;
    }
  }

  void _validateCommittedRunAuthority(
    String committedRoot, {
    required String stateRoot,
    required String ownerKind,
    required String ownerId,
  }) {
    final runRoot = p.join(stateRoot, 'runs', ownerId);
    final caseAuthorityRoot = p.join(runRoot, 'cases');
    final reportAuthorityRoot = p.join(runRoot, 'report');
    final confined =
        p.isWithin(caseAuthorityRoot, committedRoot) ||
        p.equals(reportAuthorityRoot, committedRoot);
    if (ownerKind != 'run' || !confined) {
      throw const FileSystemException(
        'Committed bundle root is outside its run owner authority.',
      );
    }
  }

  Future<String> _canonicalProducerRoot(String stateRoot) async {
    final directory = Directory(producerRoot);
    if (!await directory.exists()) {
      throw FileSystemException(
        'Worker artifact producer root is unavailable.',
        producerRoot,
      );
    }
    final canonical = p.normalize(await directory.resolveSymbolicLinks());
    if (!p.equals(canonical, producerRoot) ||
        !p.isWithin(stateRoot, canonical)) {
      throw FileSystemException(
        'Worker artifact producer root escapes state ownership.',
        producerRoot,
      );
    }
    return canonical;
  }

  Future<String> _canonicalCommittedRoot(
    String committedRoot, {
    required String stateRoot,
  }) async {
    final normalized = p.normalize(committedRoot);
    if (!p.isAbsolute(normalized) || !p.isWithin(stateRoot, normalized)) {
      throw const FileSystemException(
        'Committed artifact root is outside worker state.',
      );
    }
    final type = await FileSystemEntity.type(normalized, followLinks: false);
    if (type != FileSystemEntityType.directory) {
      throw const FileSystemException(
        'Committed artifact root is not a directory.',
      );
    }
    final canonical = p.normalize(
      await Directory(normalized).resolveSymbolicLinks(),
    );
    if (!p.equals(canonical, normalized) || !p.isWithin(stateRoot, canonical)) {
      throw const FileSystemException(
        'Committed artifact root is not canonical and confined.',
      );
    }
    return canonical;
  }

  Future<String> _canonicalStateRoot() async {
    final directory = Directory(stateRoot);
    if (!await directory.exists()) {
      throw FileSystemException('Worker state root is unavailable.', stateRoot);
    }
    final canonical = p.normalize(await directory.resolveSymbolicLinks());
    if (!p.equals(canonical, stateRoot)) {
      throw FileSystemException(
        'Worker artifact state root must remain canonical.',
        stateRoot,
      );
    }
    return canonical;
  }

  Future<void> _validateInStateSource(
    String sourcePath, {
    required String root,
    required bool allowDirectory,
  }) async {
    final type = await FileSystemEntity.type(sourcePath, followLinks: false);
    final allowed =
        type == FileSystemEntityType.file ||
        allowDirectory && type == FileSystemEntityType.directory;
    if (!allowed) {
      throw FileSystemException(
        'Retained artifact source has an invalid type.',
        sourcePath,
      );
    }
    await _validateInStateEntity(sourcePath, type: type, root: root);
    if (type == FileSystemEntityType.directory) {
      await for (final entity in Directory(
        sourcePath,
      ).list(recursive: true, followLinks: false)) {
        final nestedType = await FileSystemEntity.type(
          entity.path,
          followLinks: false,
        );
        if (nestedType != FileSystemEntityType.file &&
            nestedType != FileSystemEntityType.directory) {
          throw FileSystemException(
            'Retained artifact directory contains an invalid entry.',
            entity.path,
          );
        }
        await _validateInStateEntity(entity.path, type: nestedType, root: root);
      }
    }
  }

  Future<void> _validateInStateEntity(
    String sourcePath, {
    required FileSystemEntityType type,
    required String root,
  }) async {
    final canonical = p.normalize(
      type == FileSystemEntityType.directory
          ? await Directory(sourcePath).resolveSymbolicLinks()
          : await File(sourcePath).resolveSymbolicLinks(),
    );
    if (!p.equals(canonical, sourcePath) ||
        (!p.equals(root, canonical) && !p.isWithin(root, canonical))) {
      throw FileSystemException(
        'Retained artifact source escapes the worker state root.',
        sourcePath,
      );
    }
    if (type == FileSystemEntityType.file) {
      await _assertReadable(File(sourcePath));
    }
  }

  Future<void> _assertReadable(File file) async {
    RandomAccessFile? handle;
    try {
      handle = await file.open(mode: FileMode.read);
      await handle.read(1);
    } finally {
      await handle?.close();
    }
  }

  Future<String> _copyProducerFile(
    String sourcePath, {
    required String root,
    required String producerRoot,
    required String ownerKind,
    required String ownerId,
  }) async {
    if (!p.isWithin(producerRoot, sourcePath) ||
        await FileSystemEntity.type(sourcePath, followLinks: false) !=
            FileSystemEntityType.file) {
      throw FileSystemException(
        'Artifact source is outside the worker producer root.',
        sourcePath,
      );
    }
    final canonicalSource = p.normalize(
      await File(sourcePath).resolveSymbolicLinks(),
    );
    if (!p.equals(canonicalSource, sourcePath) ||
        !p.isWithin(producerRoot, canonicalSource)) {
      throw FileSystemException(
        'Artifact source is not canonical and producer-confined.',
        sourcePath,
      );
    }
    final parent = await _retainedOwnerDirectory(
      root,
      ownerKind: ownerKind,
      ownerId: ownerId,
    );
    final token = _tokenGenerator.nextToken(byteLength: 24);
    final extension = p.extension(canonicalSource);
    final target = File(p.join(parent.path, 'artifact_$token$extension'));
    final staging = File(p.join(parent.path, '.artifact_$token.tmp'));
    RandomAccessFile? sourceHandle;
    IOSink? sink;
    var renamed = false;
    try {
      sourceHandle = await File(canonicalSource).open(mode: FileMode.read);
      final afterType = await FileSystemEntity.type(
        sourcePath,
        followLinks: false,
      );
      final afterCanonical = afterType == FileSystemEntityType.file
          ? p.normalize(await File(sourcePath).resolveSymbolicLinks())
          : null;
      if (afterCanonical == null ||
          !p.equals(afterCanonical, canonicalSource)) {
        throw FileSystemException(
          'Artifact source changed while opening.',
          sourcePath,
        );
      }
      sink = staging.openWrite(mode: FileMode.writeOnly);
      while (true) {
        final chunk = await sourceHandle.read(64 * 1024);
        if (chunk.isEmpty) break;
        sink.add(chunk);
      }
      await sink.flush();
      await sink.close();
      sink = null;
      await sourceHandle.close();
      sourceHandle = null;
      await _permissionHardener.hardenFile(staging);
      await staging.rename(target.path);
      renamed = true;
      await _directorySyncer.sync(parent.path);
      return p.normalize(target.path);
    } catch (_) {
      try {
        await sourceHandle?.close();
        await sink?.close();
      } finally {
        if (await staging.exists()) await staging.delete();
        if (renamed && await target.exists()) await target.delete();
      }
      rethrow;
    }
  }

  Future<CockpitWorkerCommittedBundlePlan> _planCommittedBundle(
    String sourceRoot, {
    required String stateRoot,
    required String ownerKind,
    required String ownerId,
  }) async {
    final entries = List<_CommittedBundleEntry>.unmodifiable(
      await _snapshotDirectory(sourceRoot),
    );
    final ownerRoot = _retainedOwnerRoot(
      stateRoot,
      ownerKind: ownerKind,
      ownerId: ownerId,
    );
    if (_committedCopies[sourceRoot] case final retained?) {
      _validatePlannedRetainedPath(retained, ownerRoot: ownerRoot);
      await _validateInStateSource(
        retained,
        root: ownerRoot,
        allowDirectory: true,
      );
      final retainedEntries = await _snapshotDirectory(retained);
      if (!_sameDirectorySnapshot(entries, retainedEntries)) {
        throw const FileSystemException(
          'Previously retained bundle does not match its committed source.',
        );
      }
      return CockpitWorkerCommittedBundlePlan._(
        sourcePath: sourceRoot,
        retainedPath: retained,
        retainerIdentity: _identity,
        stateRoot: stateRoot,
        ownerKind: ownerKind,
        ownerId: ownerId,
        newlyCreated: false,
        entries: entries,
      );
    }
    final token = _tokenGenerator.nextToken(byteLength: 24);
    final retained = p.normalize(p.join(ownerRoot, 'bundle_$token'));
    _validatePlannedRetainedPath(retained, ownerRoot: ownerRoot);
    return CockpitWorkerCommittedBundlePlan._(
      sourcePath: sourceRoot,
      retainedPath: retained,
      retainerIdentity: _identity,
      stateRoot: stateRoot,
      ownerKind: ownerKind,
      ownerId: ownerId,
      newlyCreated: true,
      entries: entries,
    );
  }

  Future<List<_CommittedBundleEntry>> _snapshotDirectory(String root) async {
    final entries = <_CommittedBundleEntry>[];
    await for (final entity in Directory(
      root,
    ).list(recursive: true, followLinks: false)) {
      final type = await FileSystemEntity.type(entity.path, followLinks: false);
      if (type != FileSystemEntityType.file &&
          type != FileSystemEntityType.directory) {
        throw FileSystemException(
          'Committed bundle contains an invalid entry.',
          entity.path,
        );
      }
      final canonical = p.normalize(
        type == FileSystemEntityType.directory
            ? await Directory(entity.path).resolveSymbolicLinks()
            : await File(entity.path).resolveSymbolicLinks(),
      );
      if (!p.equals(canonical, p.normalize(entity.path)) ||
          !p.isWithin(root, canonical)) {
        throw FileSystemException(
          'Committed bundle entry escapes its root.',
          entity.path,
        );
      }
      entries.add(
        _CommittedBundleEntry(
          relativePath: p.relative(entity.path, from: root),
          directory: type == FileSystemEntityType.directory,
          sizeBytes: type == FileSystemEntityType.file
              ? await File(entity.path).length()
              : null,
          sha256: type == FileSystemEntityType.file
              ? (await _digest(File(entity.path))).toString()
              : null,
        ),
      );
    }
    entries.sort((left, right) {
      final depth = p
          .split(left.relativePath)
          .length
          .compareTo(p.split(right.relativePath).length);
      if (depth != 0) return depth;
      if (left.directory != right.directory) return left.directory ? -1 : 1;
      return left.relativePath.compareTo(right.relativePath);
    });
    return entries;
  }

  bool _sameDirectorySnapshot(
    List<_CommittedBundleEntry> before,
    List<_CommittedBundleEntry> after,
  ) {
    if (before.length != after.length) return false;
    for (var index = 0; index < before.length; index += 1) {
      if (before[index].relativePath != after[index].relativePath ||
          before[index].directory != after[index].directory ||
          before[index].sizeBytes != after[index].sizeBytes ||
          before[index].sha256 != after[index].sha256) {
        return false;
      }
    }
    return true;
  }

  Future<void> _copyVerifiedFile(
    File source,
    File target, {
    required _CommittedBundleEntry expected,
  }) async {
    final canonicalSource = p.normalize(await source.resolveSymbolicLinks());
    if (!p.equals(canonicalSource, p.normalize(source.path))) {
      throw FileSystemException(
        'Committed artifact source is not canonical.',
        source.path,
      );
    }
    RandomAccessFile? sourceHandle;
    RandomAccessFile? targetHandle;
    try {
      sourceHandle = await source.open(mode: FileMode.read);
      final length = await sourceHandle.length();
      targetHandle = await target.open(mode: FileMode.write);
      var copied = 0;
      while (true) {
        final chunk = await sourceHandle.read(64 * 1024);
        if (chunk.isEmpty) break;
        copied += chunk.length;
        await targetHandle.writeFrom(chunk);
      }
      await targetHandle.flush();
      await targetHandle.close();
      targetHandle = null;
      final finalLength = await sourceHandle.length();
      await sourceHandle.close();
      sourceHandle = null;
      final afterType = await FileSystemEntity.type(
        source.path,
        followLinks: false,
      );
      final afterCanonical = afterType == FileSystemEntityType.file
          ? p.normalize(await source.resolveSymbolicLinks())
          : null;
      final targetDigest = await _digest(target);
      if (expected.directory ||
          expected.sizeBytes != length ||
          expected.sha256 != targetDigest.toString() ||
          copied != length ||
          finalLength != length ||
          afterCanonical == null ||
          !p.equals(afterCanonical, canonicalSource) ||
          await _digest(source) != targetDigest) {
        throw FileSystemException(
          'Committed artifact changed while being retained.',
          source.path,
        );
      }
      await _permissionHardener.hardenFile(target);
      await _directorySyncer.sync(target.parent.path);
    } finally {
      await sourceHandle?.close();
      await targetHandle?.close();
    }
  }

  Future<Digest> _digest(File file) => sha256.bind(file.openRead()).first;

  void _validatePlannedRetainedPath(
    String retainedPath, {
    required String ownerRoot,
  }) {
    final normalized = p.normalize(retainedPath);
    final name = p.basename(normalized);
    if (!p.equals(normalized, retainedPath) ||
        !p.equals(p.dirname(normalized), ownerRoot) ||
        !RegExp(r'^bundle_[A-Za-z0-9_-]{32}$').hasMatch(name)) {
      throw const FileSystemException(
        'Committed bundle plan has invalid retained authority.',
      );
    }
  }

  Future<Directory> _retainedOwnerDirectory(
    String root, {
    required String ownerKind,
    required String ownerId,
  }) async {
    var parent = Directory(root);
    final components = ownerKind == 'run'
        ? <String>['runs', ownerId, 'artifacts']
        : <String>['retained_artifacts', ownerKind, ownerId];
    for (final component in components) {
      final directory = Directory(p.join(parent.path, component));
      final type = await FileSystemEntity.type(
        directory.path,
        followLinks: false,
      );
      final created = type == FileSystemEntityType.notFound;
      if (created) {
        await directory.create();
      } else if (type != FileSystemEntityType.directory) {
        throw FileSystemException(
          'Retained artifact owner path is invalid.',
          directory.path,
        );
      }
      final canonical = p.normalize(await directory.resolveSymbolicLinks());
      if (!p.equals(canonical, p.normalize(directory.path)) ||
          !p.isWithin(root, canonical)) {
        throw FileSystemException(
          'Retained artifact owner path escapes worker state.',
          directory.path,
        );
      }
      await _permissionHardener.hardenDirectory(directory);
      if (created) await _directorySyncer.sync(parent.path);
      parent = directory;
    }
    return parent;
  }

  String _retainedOwnerRoot(
    String root, {
    required String ownerKind,
    required String ownerId,
  }) => ownerKind == 'run'
      ? p.join(root, 'runs', ownerId, 'artifacts')
      : p.join(root, 'retained_artifacts', ownerKind, ownerId);
}

final class _CommittedBundleEntry {
  const _CommittedBundleEntry({
    required this.relativePath,
    required this.directory,
    required this.sizeBytes,
    required this.sha256,
  });

  final String relativePath;
  final bool directory;
  final int? sizeBytes;
  final String? sha256;
}
