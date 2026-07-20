import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;

import 'cockpit_home.dart';
import 'cockpit_permissions.dart';

final class CockpitStorageException implements Exception {
  const CockpitStorageException({
    required this.code,
    required this.path,
    required this.diagnostic,
  });

  final String code;
  final String path;
  final String diagnostic;

  @override
  String toString() => 'CockpitStorageException($code, $path): $diagnostic';
}

abstract interface class CockpitJsonCodec<T> {
  T decode(Object? json);

  Object? encode(T value);
}

abstract interface class CockpitDirectorySyncer {
  Future<void> sync(String directoryPath);
}

final class CockpitSystemDirectorySyncer implements CockpitDirectorySyncer {
  const CockpitSystemDirectorySyncer(this.platform);

  final CockpitHostPlatform platform;

  @override
  Future<void> sync(String directoryPath) async {
    if (platform == CockpitHostPlatform.windows) {
      return;
    }
    final arguments = platform == CockpitHostPlatform.linux
        ? <String>['-f', directoryPath]
        : const <String>[];
    final result = await Process.run('sync', arguments);
    if (result.exitCode != 0) {
      throw FileSystemException(
        'Could not synchronize directory metadata: ${_bounded(result.stderr)}',
        directoryPath,
      );
    }
  }
}

final class CockpitAtomicJsonFile {
  CockpitAtomicJsonFile({
    required this.permissionHardener,
    required this.directorySyncer,
    Random? random,
  }) : _random = random ?? Random.secure();

  final CockpitPermissionHardener permissionHardener;
  final CockpitDirectorySyncer directorySyncer;
  final Random _random;

  Future<void> write(String path, Object? value, {int? maximumBytes}) async {
    final bytes = utf8.encode('${jsonEncode(value)}\n');
    if (maximumBytes != null && bytes.length > maximumBytes) {
      throw CockpitStorageException(
        code: 'storageTooLarge',
        path: path,
        diagnostic: 'JSON document exceeds $maximumBytes bytes.',
      );
    }
    final target = File(path);
    final parent = target.parent;
    await parent.create(recursive: true);
    await permissionHardener.hardenDirectory(parent);
    final token = List<int>.generate(
      12,
      (_) => _random.nextInt(256),
    ).map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
    final temporary = File(
      p.join(parent.path, '.${p.basename(path)}.$pid.$token.tmp'),
    );
    RandomAccessFile? handle;
    try {
      handle = await temporary.open(mode: FileMode.write);
      await handle.writeFrom(bytes);
      await handle.flush();
      await handle.close();
      handle = null;
      await permissionHardener.hardenFile(temporary);
      await temporary.rename(target.path);
      await directorySyncer.sync(parent.path);
    } catch (_) {
      try {
        await handle?.close();
      } finally {
        if (await temporary.exists()) {
          await temporary.delete();
        }
      }
      rethrow;
    }
  }
}

final class CockpitLockedJsonUpdate<T, R> {
  const CockpitLockedJsonUpdate._({
    required this.value,
    required this.result,
    required this.shouldWrite,
  });

  factory CockpitLockedJsonUpdate.write(T value, R result) =>
      CockpitLockedJsonUpdate._(
        value: value,
        result: result,
        shouldWrite: true,
      );

  factory CockpitLockedJsonUpdate.readOnly(T value, R result) =>
      CockpitLockedJsonUpdate._(
        value: value,
        result: result,
        shouldWrite: false,
      );

  final T value;
  final R result;
  final bool shouldWrite;
}

typedef CockpitLockedJsonTransaction<T, R> =
    FutureOr<CockpitLockedJsonUpdate<T, R>> Function(T current);

final class CockpitLockedJsonStore<T> {
  CockpitLockedJsonStore({
    required this.path,
    required this.codec,
    required this.createInitial,
    required this.permissionHardener,
    required CockpitDirectorySyncer directorySyncer,
    this.maximumBytes = 8 * 1024 * 1024,
  }) : _atomicFile = CockpitAtomicJsonFile(
         permissionHardener: permissionHardener,
         directorySyncer: directorySyncer,
       );

  final String path;
  final CockpitJsonCodec<T> codec;
  final T Function() createInitial;
  final CockpitPermissionHardener permissionHardener;
  final int maximumBytes;
  final CockpitAtomicJsonFile _atomicFile;

  String get lockPath => '$path.lock';

  Future<T> read() => transact<T>(
    (current) => CockpitLockedJsonUpdate<T, T>.readOnly(current, current),
  );

  Future<R> transact<R>(CockpitLockedJsonTransaction<T, R> transaction) async {
    return _CockpitInProcessLocks.run(
      p.normalize(p.absolute(path)),
      () => _transactWithFileLock(transaction),
    );
  }

  Future<R> _transactWithFileLock<R>(
    CockpitLockedJsonTransaction<T, R> transaction,
  ) async {
    final target = File(path);
    await target.parent.create(recursive: true);
    await permissionHardener.hardenDirectory(target.parent);
    final lockFile = File(lockPath);
    final lockHandle = await lockFile.open(mode: FileMode.append);
    var acquired = false;
    try {
      await permissionHardener.hardenFile(lockFile);
      await lockHandle.lock(FileLock.blockingExclusive);
      acquired = true;
      final current = await _readLocked(target);
      final update = await transaction(current);
      if (update.shouldWrite) {
        await _atomicFile.write(
          path,
          codec.encode(update.value),
          maximumBytes: maximumBytes,
        );
      }
      return update.result;
    } finally {
      try {
        if (acquired) {
          await lockHandle.unlock();
        }
      } finally {
        await lockHandle.close();
      }
    }
  }

  Future<T> _readLocked(File target) async {
    if (!await target.exists()) {
      return createInitial();
    }
    final length = await target.length();
    if (length > maximumBytes) {
      throw CockpitStorageException(
        code: 'storageTooLarge',
        path: path,
        diagnostic: 'JSON document exceeds $maximumBytes bytes.',
      );
    }
    try {
      final source = await target.readAsString();
      return codec.decode(jsonDecode(source));
    } on CockpitStorageException {
      rethrow;
    } on Object catch (error) {
      throw CockpitStorageException(
        code: 'storageCorrupt',
        path: path,
        diagnostic: _bounded(error),
      );
    }
  }
}

abstract final class _CockpitInProcessLocks {
  static final Map<String, Future<void>> _tails = <String, Future<void>>{};

  static Future<R> run<R>(String path, Future<R> Function() action) async {
    final previous = _tails[path] ?? Future<void>.value();
    final turn = Completer<void>();
    _tails[path] = turn.future;
    await previous;
    try {
      return await action();
    } finally {
      turn.complete();
      if (identical(_tails[path], turn.future)) {
        _tails.remove(path);
      }
    }
  }
}

String _bounded(Object? value) {
  final text = value
      .toString()
      .replaceAll('\n', ' ')
      .replaceAll('\r', ' ')
      .replaceAll('\t', ' ')
      .trim();
  return text.length <= 256 ? text : '${text.substring(0, 256)}...';
}
