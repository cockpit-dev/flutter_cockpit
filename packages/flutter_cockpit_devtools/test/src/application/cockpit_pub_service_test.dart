import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file/memory.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_pub_service.dart';
import 'package:flutter_cockpit_devtools/src/infrastructure/cockpit_file_system.dart';
import 'package:flutter_cockpit_devtools/src/infrastructure/cockpit_process_manager.dart';
import 'package:flutter_cockpit_devtools/src/infrastructure/cockpit_sdk_environment.dart';
import 'package:test/test.dart';

void main() {
  test('uses flutter pub in Flutter workspaces and bounds output', () async {
    final fileSystem = MemoryFileSystem();
    fileSystem.file('/workspace/app/pubspec.yaml')
      ..createSync(recursive: true)
      ..writeAsStringSync(
        'name: app\n\ndependencies:\n  flutter:\n    sdk: flutter\n',
      );
    final processManager = _RecordingPubProcessManager();
    final service = CockpitPubService(
      fileSystem: LocalCockpitFileSystem(fileSystem: fileSystem),
      processManager: processManager,
      sdkEnvironment: const CockpitSdkEnvironment(
        dartExecutable: 'dart-sdk',
        flutterExecutable: 'flutter-sdk',
      ),
    );

    final result = await service.run(
      const CockpitPubRequest(
        workspaceRoot: '/workspace/app',
        command: CockpitPubCommand.add,
        packages: <String>['collection'],
        maxOutputChars: 20,
      ),
    );

    expect(result.toolchain.name, 'flutter');
    expect(result.command.executable, 'flutter-sdk');
    expect(
      result.command.arguments,
      <String>['pub', 'add', 'collection'],
    );
    expect(result.stdoutPreview, isNotNull);
    expect(result.stdoutTruncated, isTrue);
  });

  test('rejects packages for commands that do not accept them', () async {
    final fileSystem = MemoryFileSystem();
    fileSystem.file('/workspace/pkg/pubspec.yaml')
      ..createSync(recursive: true)
      ..writeAsStringSync('name: pkg\n');

    final service = CockpitPubService(
      fileSystem: LocalCockpitFileSystem(fileSystem: fileSystem),
      processManager: _RecordingPubProcessManager(),
    );

    expect(
      () => service.run(
        const CockpitPubRequest(
          workspaceRoot: '/workspace/pkg',
          command: CockpitPubCommand.deps,
          packages: <String>['collection'],
        ),
      ),
      throwsA(isA<Exception>()),
    );
  });
}

final class _RecordingPubProcessManager implements CockpitProcessManager {
  @override
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    bool includeParentEnvironment = true,
    bool runInShell = false,
    Encoding? stdoutEncoding,
    Encoding? stderrEncoding,
  }) async {
    return ProcessResult(
      1,
      0,
      utf8.encode(jsonEncode(<String, Object?>{
        'executable': executable,
        'arguments': arguments,
        'working_directory': workingDirectory,
        'message': 'This output is intentionally long to exercise truncation.',
      })),
      utf8.encode(''),
    );
  }

  @override
  Future<Process> start(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    bool includeParentEnvironment = true,
    bool runInShell = false,
    ProcessStartMode mode = ProcessStartMode.normal,
  }) async {
    return _CompletedFakeProcess(
      stdout: jsonEncode(<String, Object?>{
        'executable': executable,
        'arguments': arguments,
        'working_directory': workingDirectory,
        'message': 'This output is intentionally long to exercise truncation.',
      }),
    );
  }
}

final class _CompletedFakeProcess implements Process {
  _CompletedFakeProcess({
    required String stdout,
    String stderr = '',
  })  : _stdout = Stream<List<int>>.value(utf8.encode(stdout)),
        _stderr = Stream<List<int>>.value(utf8.encode(stderr));

  final Stream<List<int>> _stdout;
  final Stream<List<int>> _stderr;
  final StreamController<List<int>> _stdinController =
      StreamController<List<int>>();
  @override
  Future<int> get exitCode => Future<int>.value(0);

  @override
  int get pid => 1;

  @override
  IOSink get stdin => IOSink(_stdinController.sink);

  @override
  Stream<List<int>> get stderr => _stderr;

  @override
  Stream<List<int>> get stdout => _stdout;

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    _stdinController.close();
    return true;
  }
}
