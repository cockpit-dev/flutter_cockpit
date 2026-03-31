import 'dart:convert';
import 'dart:io';
import 'dart:async';

import 'package:file/memory.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_analyze_workspace_service.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_apply_workspace_fixes_service.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_format_workspace_service.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_run_workspace_tests_service.dart';
import 'package:flutter_cockpit_devtools/src/infrastructure/cockpit_file_system.dart';
import 'package:flutter_cockpit_devtools/src/infrastructure/cockpit_process_manager.dart';
import 'package:flutter_cockpit_devtools/src/infrastructure/cockpit_sdk_environment.dart';
import 'package:test/test.dart';

void main() {
  test('uses flutter analyze for flutter workspaces', () async {
    final fileSystem = MemoryFileSystem();
    fileSystem.file('/workspace/app/pubspec.yaml')
      ..createSync(recursive: true)
      ..writeAsStringSync(
          'name: app\n\ndependencies:\n  flutter:\n    sdk: flutter\n');
    final processManager = _RecordingProcessManager();

    final service = CockpitAnalyzeWorkspaceService(
      fileSystem: LocalCockpitFileSystem(fileSystem: fileSystem),
      processManager: processManager,
      sdkEnvironment: const CockpitSdkEnvironment(
        dartExecutable: 'dart-sdk',
        flutterExecutable: 'flutter-sdk',
      ),
    );

    final result = await service.analyze(
      const CockpitAnalyzeWorkspaceRequest(workspaceRoot: '/workspace/app'),
    );

    expect(result.command.executable, 'flutter-sdk');
    expect(result.command.arguments, <String>['analyze']);
  });

  test('runs format, tests, and fixes through bounded workspace commands',
      () async {
    final fileSystem = MemoryFileSystem();
    fileSystem.file('/workspace/pkg/pubspec.yaml')
      ..createSync(recursive: true)
      ..writeAsStringSync('name: pkg\n');
    final processManager = _RecordingProcessManager();
    final wrappedFileSystem = LocalCockpitFileSystem(fileSystem: fileSystem);

    final formatResult = await CockpitFormatWorkspaceService(
      fileSystem: wrappedFileSystem,
      processManager: processManager,
      sdkEnvironment: const CockpitSdkEnvironment(
        dartExecutable: 'dart-sdk',
        flutterExecutable: 'flutter-sdk',
      ),
    ).format(
      const CockpitFormatWorkspaceRequest(workspaceRoot: '/workspace/pkg'),
    );
    expect(formatResult.command.arguments, <String>['format', '.']);

    final testResult = await CockpitRunWorkspaceTestsService(
      fileSystem: wrappedFileSystem,
      processManager: processManager,
      sdkEnvironment: const CockpitSdkEnvironment(
        dartExecutable: 'dart-sdk',
        flutterExecutable: 'flutter-sdk',
      ),
    ).run(
      const CockpitRunWorkspaceTestsRequest(workspaceRoot: '/workspace/pkg'),
    );
    expect(testResult.command.arguments, <String>['test']);

    final fixResult = await CockpitApplyWorkspaceFixesService(
      fileSystem: wrappedFileSystem,
      processManager: processManager,
      sdkEnvironment: const CockpitSdkEnvironment(
        dartExecutable: 'dart-sdk',
        flutterExecutable: 'flutter-sdk',
      ),
    ).apply(
      const CockpitApplyWorkspaceFixesRequest(workspaceRoot: '/workspace/pkg'),
    );
    expect(fixResult.command.arguments, <String>['fix', '--apply']);
  });

  test('workspace commands time out instead of hanging forever', () async {
    final fileSystem = MemoryFileSystem();
    fileSystem.file('/workspace/pkg/pubspec.yaml')
      ..createSync(recursive: true)
      ..writeAsStringSync('name: pkg\n');

    final service = CockpitFormatWorkspaceService(
      fileSystem: LocalCockpitFileSystem(fileSystem: fileSystem),
      processManager: _HangingProcessManager(),
      sdkEnvironment: const CockpitSdkEnvironment(
        dartExecutable: 'dart-sdk',
        flutterExecutable: 'flutter-sdk',
      ),
    );

    expect(
      () => service.format(
        const CockpitFormatWorkspaceRequest(
          workspaceRoot: '/workspace/pkg',
          timeout: Duration(milliseconds: 20),
        ),
      ),
      throwsA(isA<Exception>()),
    );
  });
}

final class _RecordingProcessManager implements CockpitProcessManager {
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
      jsonEncode(<String, Object?>{
        'executable': executable,
        'arguments': arguments,
        'workingDirectory': workingDirectory,
      }),
      '',
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
        'workingDirectory': workingDirectory,
      }),
    );
  }
}

final class _HangingProcessManager implements CockpitProcessManager {
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
    throw UnimplementedError();
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
    return _FakeProcess();
  }
}

final class _FakeProcess implements Process {
  final StreamController<List<int>> _stdoutController =
      StreamController<List<int>>();
  final StreamController<List<int>> _stderrController =
      StreamController<List<int>>();
  final StreamController<List<int>> _stdinController =
      StreamController<List<int>>();

  @override
  Future<int> get exitCode => Completer<int>().future;

  @override
  int get pid => 1;

  @override
  IOSink get stdin => IOSink(_stdinController.sink);

  @override
  Stream<List<int>> get stderr => _stderrController.stream;

  @override
  Stream<List<int>> get stdout => _stdoutController.stream;

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    _stdoutController.close();
    _stderrController.close();
    _stdinController.close();
    return true;
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
