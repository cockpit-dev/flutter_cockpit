import 'dart:convert';
import 'dart:io';

import 'package:file/memory.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_application_service_exception.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_create_project_service.dart';
import 'package:flutter_cockpit_devtools/src/infrastructure/cockpit_file_system.dart';
import 'package:flutter_cockpit_devtools/src/infrastructure/cockpit_process_manager.dart';
import 'package:flutter_cockpit_devtools/src/infrastructure/cockpit_sdk_environment.dart';
import 'package:test/test.dart';

void main() {
  test('creates a flutter project inside an allowed root', () async {
    final processManager = _FakeProcessManager();
    final fileSystem = MemoryFileSystem();
    fileSystem.directory('/workspace/apps').createSync(recursive: true);

    final service = CockpitCreateProjectService(
      processManager: processManager,
      fileSystem: LocalCockpitFileSystem(fileSystem: fileSystem),
      sdkEnvironment: const CockpitSdkEnvironment(
        dartExecutable: 'dart-sdk',
        flutterExecutable: 'flutter-sdk',
      ),
    );

    final result = await service.create(
      const CockpitCreateProjectRequest(
        parentDirectory: '/workspace/apps',
        projectName: 'todo_app',
        template: CockpitProjectTemplate.flutterApp,
        organization: 'com.example',
        platforms: <String>['android', 'ios'],
        allowedRoots: <String>['/workspace'],
      ),
    );

    expect(result.projectDirectory, '/workspace/apps/todo_app');
    expect(result.command.executable, 'flutter-sdk');
    expect(result.success, isTrue);
    expect(
      result.command.arguments,
      containsAll(<String>[
        'create',
        '--org',
        'com.example',
        '--platforms=android,ios',
        '/workspace/apps/todo_app',
      ]),
    );
  });

  test('rejects project creation outside allowed roots', () async {
    final service = CockpitCreateProjectService(
      processManager: _FakeProcessManager(),
      fileSystem: LocalCockpitFileSystem(fileSystem: MemoryFileSystem()),
    );

    expect(
      () => service.create(
        const CockpitCreateProjectRequest(
          parentDirectory: '/tmp',
          projectName: 'todo_app',
          template: CockpitProjectTemplate.flutterApp,
          allowedRoots: <String>['/workspace'],
        ),
      ),
      throwsA(isA<CockpitApplicationServiceException>()),
    );
  });
}

final class _FakeProcessManager implements CockpitProcessManager {
  String? executable;
  List<String>? arguments;
  String? workingDirectory;

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
    this.executable = executable;
    this.arguments = arguments;
    this.workingDirectory = workingDirectory;
    return ProcessResult(1, 0, 'created', '');
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
  }) {
    throw UnimplementedError();
  }
}
