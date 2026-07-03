import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_cockpit_protocol/flutter_cockpit_protocol.dart';
import 'package:cockpit/src/application/cockpit_application_service_exception.dart';
import 'package:cockpit/src/application/cockpit_run_shell_service.dart';
import 'package:cockpit/src/infrastructure/cockpit_process_manager.dart';
import 'package:cockpit/src/targets/cockpit_target_handle.dart';
import 'package:test/test.dart';

void main() {
  test(
    'run shell executes host commands and returns structured output',
    () async {
      final service = CockpitRunShellService(
        processManager: _CallbackProcessManager(
          onStart:
              ({
                required String executable,
                required List<String> arguments,
                String? workingDirectory,
              }) async =>
                  _CompletedShellProcess(stdout: 'Dart SDK version: 3.10.8'),
        ),
      );

      final result = await service.run(
        const CockpitRunShellRequest(command: <String>['dart', '--version']),
      );

      expect(result.success, isTrue);
      expect(result.scope, 'host');
      expect(result.command, <String>['dart', '--version']);
      expect(result.recommendedNextStep, 'continue');
    },
  );

  test('run shell times out and kills hanging host commands', () async {
    final process = _HangingShellProcess(stdout: 'started\n');
    final service = CockpitRunShellService(
      processManager: _SingleProcessManager(process),
    );

    await expectLater(
      () => service.run(
        const CockpitRunShellRequest(
          command: <String>['sleep', '99'],
          timeout: Duration(milliseconds: 20),
        ),
      ),
      throwsA(
        isA<CockpitApplicationServiceException>()
            .having((error) => error.code, 'code', 'shellCommandTimedOut')
            .having(
              (error) => error.details['stdoutPreview'],
              'stdoutPreview',
              contains('started'),
            ),
      ),
    );
    expect(process.killSignals, contains(ProcessSignal.sigkill));
  });

  test(
    'run shell executes android target commands through adb shell',
    () async {
      late String capturedExecutable;
      late List<String> capturedArguments;
      final service = CockpitRunShellService(
        processManager: _CallbackProcessManager(
          onStart:
              ({
                required String executable,
                required List<String> arguments,
                String? workingDirectory,
              }) async {
                capturedExecutable = executable;
                capturedArguments = arguments;
                return _CompletedShellProcess(stdout: '34');
              },
        ),
      );

      final result = await service.run(
        CockpitRunShellRequest(
          scope: 'target',
          target: CockpitTargetHandle(
            targetId: 'android-device',
            targetKind: CockpitTargetKind.device,
            platform: 'android',
            deviceId: 'emulator-5554',
            projectDir: '/workspace/examples/cockpit_demo',
            target: 'device',
            connection: const CockpitTargetConnection(
              baseUrl: 'http://127.0.0.1:57331',
            ),
            launchedAt: DateTime.utc(2026, 4, 11),
          ),
          command: const <String>['getprop', 'ro.build.version.sdk'],
        ),
      );

      expect(capturedExecutable, 'adb');
      expect(capturedArguments, <String>[
        '-s',
        'emulator-5554',
        'shell',
        'getprop',
        'ro.build.version.sdk',
      ]);
      expect(result.scope, 'android');
      expect(result.success, isTrue);
    },
  );

  test(
    'run shell executes ios simulator commands through simctl spawn',
    () async {
      late String capturedExecutable;
      late List<String> capturedArguments;
      final service = CockpitRunShellService(
        processManager: _CallbackProcessManager(
          onStart:
              ({
                required String executable,
                required List<String> arguments,
                String? workingDirectory,
              }) async {
                capturedExecutable = executable;
                capturedArguments = arguments;
                return _CompletedShellProcess(stdout: '');
              },
        ),
      );

      final result = await service.run(
        CockpitRunShellRequest(
          scope: 'ios',
          deviceId: 'A1B2C3D4-0000-1111-2222-333344445555',
          command: const <String>['defaults', 'read', 'com.apple.Preferences'],
        ),
      );

      expect(capturedExecutable, 'xcrun');
      expect(capturedArguments, <String>[
        'simctl',
        'spawn',
        'A1B2C3D4-0000-1111-2222-333344445555',
        '/bin/sh',
        '-lc',
        "'defaults' 'read' 'com.apple.Preferences'",
      ]);
      expect(result.scope, 'ios');
      expect(result.success, isTrue);
    },
  );

  test('run shell rejects unsupported browser shell scopes', () async {
    final service = CockpitRunShellService();

    await expectLater(
      () => service.run(
        const CockpitRunShellRequest(
          scope: 'web',
          command: <String>['echo', 'hi'],
        ),
      ),
      throwsA(
        isA<CockpitApplicationServiceException>().having(
          (error) => error.code,
          'code',
          'unsupportedShellScope',
        ),
      ),
    );
  });
}

typedef _StartHandler =
    Future<Process> Function({
      required String executable,
      required List<String> arguments,
      String? workingDirectory,
    });

final class _CallbackProcessManager implements CockpitProcessManager {
  const _CallbackProcessManager({required this.onStart});

  final _StartHandler onStart;

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
  }) {
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
  }) {
    return onStart(
      executable: executable,
      arguments: arguments,
      workingDirectory: workingDirectory,
    );
  }
}

final class _SingleProcessManager implements CockpitProcessManager {
  const _SingleProcessManager(this.process);

  final Process process;

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
  }) {
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
    return process;
  }
}

final class _CompletedShellProcess implements Process {
  _CompletedShellProcess({required String stdout, String stderr = ''})
    : _stdout = Stream<List<int>>.value(utf8.encode(stdout)),
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
    if (!_stdinController.isClosed) {
      unawaited(_stdinController.close());
    }
    return true;
  }
}

final class _HangingShellProcess implements Process {
  _HangingShellProcess({required String stdout})
    : _stdoutController = StreamController<List<int>>(),
      _stderrController = StreamController<List<int>>() {
    scheduleMicrotask(() {
      _stdoutController.add(utf8.encode(stdout));
    });
  }

  final StreamController<List<int>> _stdoutController;
  final StreamController<List<int>> _stderrController;
  final StreamController<List<int>> _stdinController =
      StreamController<List<int>>();
  final Completer<int> _exitCode = Completer<int>();
  final List<ProcessSignal> killSignals = <ProcessSignal>[];

  @override
  Future<int> get exitCode => _exitCode.future;

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
    killSignals.add(signal);
    if (!_exitCode.isCompleted) {
      _exitCode.complete(-1);
    }
    if (!_stdoutController.isClosed) {
      unawaited(_stdoutController.close());
    }
    if (!_stderrController.isClosed) {
      unawaited(_stderrController.close());
    }
    if (!_stdinController.isClosed) {
      unawaited(_stdinController.close());
    }
    return true;
  }
}
