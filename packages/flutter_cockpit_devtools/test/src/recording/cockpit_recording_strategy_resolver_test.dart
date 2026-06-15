import 'dart:io';

import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:flutter_cockpit_devtools/flutter_cockpit_devtools.dart';
import 'package:test/test.dart';

void main() {
  const autoRequest = CockpitRecordingRequest(
    purpose: CockpitRecordingPurpose.acceptance,
    name: 'acceptance-demo',
    attachToStep: true,
  );
  const nativeRequest = CockpitRecordingRequest(
    purpose: CockpitRecordingPurpose.acceptance,
    name: 'native-demo',
    mode: CockpitRecordingMode.native,
  );
  const fullRequest = CockpitRecordingRequest(
    purpose: CockpitRecordingPurpose.acceptance,
    name: 'full-demo',
    mode: CockpitRecordingMode.full,
  );
  const strictFlutterLayerRequest = CockpitRecordingRequest(
    purpose: CockpitRecordingPurpose.acceptance,
    name: 'flutter-layer-demo',
    layer: CockpitRecordingLayer.flutter,
  );
  const fallbackSystemLayerRequest = CockpitRecordingRequest(
    purpose: CockpitRecordingPurpose.acceptance,
    name: 'system-fallback-demo',
    layer: CockpitRecordingLayer.system,
    allowFallback: true,
  );

  test('prefers adb system recording for Android auto mode', () {
    final resolver = CockpitRecordingStrategyResolver(
      remoteAdapterFactory: (client) => _FakeRecordingAdapter(),
      adbAdapterFactory: (deviceId) => _FakeRecordingAdapter(),
      simctlAdapterFactory: (deviceId) => _FakeRecordingAdapter(),
    );

    final resolution = resolver.resolveDetailed(
      platform: 'android',
      recording: autoRequest,
      client: CockpitRemoteSessionClient(
        baseUri: Uri.parse('http://127.0.0.1:47331'),
      ),
      androidDeviceId: 'emulator-5554',
    );

    expect(resolution?.implementation, 'adb');
    expect(resolution?.effectiveLayer, CockpitRecordingLayer.system);
    expect(resolution?.fallbackUsed, isFalse);
    expect(resolution?.adapter, isNotNull);
  });

  test(
    'uses simctl system recording for iOS auto mode when a simulator device ID is provided',
    () {
      final resolver = CockpitRecordingStrategyResolver(
        remoteAdapterFactory: (client) => _FakeRecordingAdapter(),
        adbAdapterFactory: (deviceId) => _FakeRecordingAdapter(),
        simctlAdapterFactory: (deviceId) => _FakeRecordingAdapter(),
      );

      final resolution = resolver.resolveDetailed(
        platform: 'ios',
        recording: autoRequest,
        client: CockpitRemoteSessionClient(
          baseUri: Uri.parse('http://127.0.0.1:47331'),
        ),
        iosDeviceId: '6FD25DED-11E9-4AE9-B4B5-EDF4601981DC',
      );

      expect(resolution?.implementation, 'simctl');
      expect(resolution?.effectiveLayer, CockpitRecordingLayer.system);
      expect(resolution?.fallbackUsed, isFalse);
    },
  );

  test(
    'uses remote native recording for iOS native mode even when a simulator device ID is provided',
    () {
      final resolver = CockpitRecordingStrategyResolver(
        remoteAdapterFactory: (client) => _FakeRecordingAdapter(),
        adbAdapterFactory: (deviceId) => _FakeRecordingAdapter(),
        simctlAdapterFactory: (deviceId) => _FakeRecordingAdapter(),
      );

      final resolution = resolver.resolveDetailed(
        platform: 'ios',
        recording: nativeRequest,
        client: CockpitRemoteSessionClient(
          baseUri: Uri.parse('http://127.0.0.1:47331'),
        ),
        iosDeviceId: '6FD25DED-11E9-4AE9-B4B5-EDF4601981DC',
      );

      expect(resolution?.implementation, 'remote');
      expect(resolution?.effectiveLayer, CockpitRecordingLayer.system);
      expect(resolution?.fallbackUsed, isFalse);
    },
  );

  test(
    'uses remote recording for physical iOS device IDs instead of simctl',
    () {
      final resolver = CockpitRecordingStrategyResolver(
        remoteAdapterFactory: (client) => _FakeRecordingAdapter(),
        adbAdapterFactory: (deviceId) => _FakeRecordingAdapter(),
        simctlAdapterFactory: (deviceId) => _FakeRecordingAdapter(),
      );

      final resolution = resolver.resolveDetailed(
        platform: 'ios',
        recording: autoRequest,
        client: CockpitRemoteSessionClient(
          baseUri: Uri.parse('http://127.0.0.1:47331'),
        ),
        iosDeviceId: '00008110-0009341C2EF3801E',
      );

      expect(resolution?.implementation, 'remote');
      expect(resolution?.effectiveLayer, CockpitRecordingLayer.system);
      expect(resolution?.fallbackUsed, isFalse);
    },
  );

  test('uses host-screen recording for macOS full mode', () {
    final resolver = CockpitRecordingStrategyResolver(
      remoteAdapterFactory: (client) => _FakeRecordingAdapter(),
      adbAdapterFactory: (deviceId) => _FakeRecordingAdapter(),
      simctlAdapterFactory: (deviceId) => _FakeRecordingAdapter(),
      macosAdapterFactory: (appId) => _FakeRecordingAdapter(),
    );

    final resolution = resolver.resolveDetailed(
      platform: 'macos',
      recording: fullRequest,
      client: CockpitRemoteSessionClient(
        baseUri: Uri.parse('http://127.0.0.1:47331'),
      ),
      platformAppId: 'dev.cockpit.cockpitDemo',
      sessionHandle: CockpitRemoteSessionHandle(
        platform: 'macos',
        deviceId: 'macos',
        projectDir: '/workspace/examples/cockpit_demo',
        target: 'cockpit/main.dart',
        appId: 'dev.cockpit.cockpitDemo',
        host: '127.0.0.1',
        hostPort: 47331,
        devicePort: 47331,
        baseUrl: 'http://127.0.0.1:47331',
        launchedAt: DateTime.utc(2026, 3, 24),
      ),
    );

    expect(resolution?.implementation, 'macosHost');
    expect(resolution?.effectiveLayer, CockpitRecordingLayer.hostScreen);
    expect(resolution?.fallbackUsed, isFalse);
  });

  test('uses host-screen recording for macOS auto mode', () {
    final resolver = CockpitRecordingStrategyResolver(
      remoteAdapterFactory: (client) => _FakeRecordingAdapter(),
      adbAdapterFactory: (deviceId) => _FakeRecordingAdapter(),
      simctlAdapterFactory: (deviceId) => _FakeRecordingAdapter(),
      macosAdapterFactory: (appId) => _FakeRecordingAdapter(),
    );

    final resolution = resolver.resolveDetailed(
      platform: 'macos',
      recording: autoRequest,
      client: CockpitRemoteSessionClient(
        baseUri: Uri.parse('http://127.0.0.1:47331'),
      ),
      platformAppId: 'dev.cockpit.cockpitDemo',
    );

    expect(resolution?.implementation, 'macosHost');
    expect(resolution?.effectiveLayer, CockpitRecordingLayer.hostScreen);
    expect(resolution?.fallbackUsed, isFalse);
  });

  test('uses process-scoped host recording for Windows full mode', () {
    String? capturedAppId;
    int? capturedProcessId;
    final resolver = CockpitRecordingStrategyResolver(
      remoteAdapterFactory: (client) => _FakeRecordingAdapter(),
      adbAdapterFactory: (deviceId) => _FakeRecordingAdapter(),
      simctlAdapterFactory: (deviceId) => _FakeRecordingAdapter(),
      windowsAdapterFactory: (appId, {processId}) {
        capturedAppId = appId;
        capturedProcessId = processId;
        return _FakeRecordingAdapter();
      },
    );

    final resolution = resolver.resolveDetailed(
      platform: 'windows',
      recording: fullRequest,
      client: CockpitRemoteSessionClient(
        baseUri: Uri.parse('http://127.0.0.1:47331'),
      ),
      sessionHandle: CockpitRemoteSessionHandle(
        platform: 'windows',
        deviceId: 'windows',
        projectDir: '/workspace/examples/cockpit_demo',
        target: 'cockpit/main.dart',
        appId: 'cockpit_demo',
        processId: 4101,
        host: '127.0.0.1',
        hostPort: 47331,
        devicePort: 47331,
        baseUrl: 'http://127.0.0.1:47331',
        launchedAt: DateTime.utc(2026, 3, 24),
      ),
    );

    expect(resolution?.implementation, 'windowsHost');
    expect(resolution?.effectiveLayer, CockpitRecordingLayer.hostScreen);
    expect(resolution?.fallbackUsed, isFalse);
    expect(capturedAppId, 'cockpit_demo');
    expect(capturedProcessId, 4101);
  });

  test('uses process-scoped host recording for Windows auto mode', () {
    String? capturedAppId;
    int? capturedProcessId;
    final resolver = CockpitRecordingStrategyResolver(
      remoteAdapterFactory: (client) => _FakeRecordingAdapter(),
      adbAdapterFactory: (deviceId) => _FakeRecordingAdapter(),
      simctlAdapterFactory: (deviceId) => _FakeRecordingAdapter(),
      windowsAdapterFactory: (appId, {processId}) {
        capturedAppId = appId;
        capturedProcessId = processId;
        return _FakeRecordingAdapter();
      },
    );

    final resolution = resolver.resolveDetailed(
      platform: 'windows',
      recording: autoRequest,
      client: CockpitRemoteSessionClient(
        baseUri: Uri.parse('http://127.0.0.1:47331'),
      ),
      platformAppId: 'cockpit_demo',
      processId: 4101,
    );

    expect(resolution?.implementation, 'windowsHost');
    expect(resolution?.effectiveLayer, CockpitRecordingLayer.hostScreen);
    expect(resolution?.fallbackUsed, isFalse);
    expect(capturedAppId, 'cockpit_demo');
    expect(capturedProcessId, 4101);
  });

  test(
    'uses process-scoped host recording for Windows full mode when only a process id is available',
    () {
      String? capturedAppId;
      int? capturedProcessId;
      final resolver = CockpitRecordingStrategyResolver(
        remoteAdapterFactory: (client) => _FakeRecordingAdapter(),
        adbAdapterFactory: (deviceId) => _FakeRecordingAdapter(),
        simctlAdapterFactory: (deviceId) => _FakeRecordingAdapter(),
        windowsAdapterFactory: (appId, {processId}) {
          capturedAppId = appId;
          capturedProcessId = processId;
          return _FakeRecordingAdapter();
        },
      );

      final resolution = resolver.resolveDetailed(
        platform: 'windows',
        recording: fullRequest,
        client: CockpitRemoteSessionClient(
          baseUri: Uri.parse('http://127.0.0.1:47331'),
        ),
        sessionHandle: CockpitRemoteSessionHandle(
          platform: 'windows',
          deviceId: 'windows',
          projectDir: '/workspace/examples/cockpit_demo',
          target: 'cockpit/main.dart',
          appId: 'app-with-unknown-platform-id',
          platformAppIdKnown: false,
          processId: 4101,
          host: '127.0.0.1',
          hostPort: 47331,
          devicePort: 47331,
          baseUrl: 'http://127.0.0.1:47331',
          launchedAt: DateTime.utc(2026, 3, 24),
        ),
      );

      expect(resolution?.implementation, 'windowsHost');
      expect(resolution?.effectiveLayer, CockpitRecordingLayer.hostScreen);
      expect(resolution?.fallbackUsed, isFalse);
      expect(capturedAppId, 'pid-4101');
      expect(capturedProcessId, 4101);
    },
  );

  test('reuses an active Windows host recording session by process id', () {
    addTearDown(() {
      cockpitClearActiveHostRecordingSession('windows:4101');
    });
    cockpitStoreActiveHostRecordingSession(
      'windows:4101',
      CockpitHostRecordingRuntimeSession(
        process: _FakeProcess(),
        request: autoRequest,
        outputFile: File('/tmp/windows-active-recording.mp4'),
        stderrSubscription: null,
        stopwatch: Stopwatch(),
      ),
    );

    final resolver = CockpitRecordingStrategyResolver(
      remoteAdapterFactory: (client) => _FakeRecordingAdapter(),
      adbAdapterFactory: (deviceId) => _FakeRecordingAdapter(),
      simctlAdapterFactory: (deviceId) => _FakeRecordingAdapter(),
      windowsAdapterFactory: (appId, {processId}) => _FakeRecordingAdapter(),
    );

    final resolution = resolver.resolveDetailed(
      platform: 'windows',
      recording: autoRequest,
      client: CockpitRemoteSessionClient(
        baseUri: Uri.parse('http://127.0.0.1:47331'),
      ),
      sessionHandle: CockpitRemoteSessionHandle(
        platform: 'windows',
        deviceId: 'windows',
        projectDir: '/workspace/examples/cockpit_demo',
        target: 'cockpit/main.dart',
        appId: 'cockpit_demo',
        processId: 4101,
        host: '127.0.0.1',
        hostPort: 47331,
        devicePort: 47331,
        baseUrl: 'http://127.0.0.1:47331',
        launchedAt: DateTime.utc(2026, 4, 13),
      ),
      preferActiveHostSession: true,
    );

    expect(resolution?.implementation, 'windowsHost');
    expect(resolution?.effectiveLayer, CockpitRecordingLayer.hostScreen);
  });

  test('uses process-scoped host recording for Linux full mode', () {
    String? capturedAppId;
    int? capturedProcessId;
    final resolver = CockpitRecordingStrategyResolver(
      remoteAdapterFactory: (client) => _FakeRecordingAdapter(),
      adbAdapterFactory: (deviceId) => _FakeRecordingAdapter(),
      simctlAdapterFactory: (deviceId) => _FakeRecordingAdapter(),
      linuxAdapterFactory: (appId, {processId}) {
        capturedAppId = appId;
        capturedProcessId = processId;
        return _FakeRecordingAdapter();
      },
    );

    final resolution = resolver.resolveDetailed(
      platform: 'linux',
      recording: fullRequest,
      client: CockpitRemoteSessionClient(
        baseUri: Uri.parse('http://127.0.0.1:47331'),
      ),
      sessionHandle: CockpitRemoteSessionHandle(
        platform: 'linux',
        deviceId: 'linux',
        projectDir: '/workspace/examples/cockpit_demo',
        target: 'cockpit/main.dart',
        appId: 'cockpit_demo',
        processId: 5101,
        host: '127.0.0.1',
        hostPort: 47331,
        devicePort: 47331,
        baseUrl: 'http://127.0.0.1:47331',
        launchedAt: DateTime.utc(2026, 3, 24),
      ),
    );

    expect(resolution?.implementation, 'linuxHost');
    expect(resolution?.effectiveLayer, CockpitRecordingLayer.hostScreen);
    expect(resolution?.fallbackUsed, isFalse);
    expect(capturedAppId, 'cockpit_demo');
    expect(capturedProcessId, 5101);
  });

  test('uses process-scoped host recording for Linux auto mode', () {
    String? capturedAppId;
    int? capturedProcessId;
    final resolver = CockpitRecordingStrategyResolver(
      remoteAdapterFactory: (client) => _FakeRecordingAdapter(),
      adbAdapterFactory: (deviceId) => _FakeRecordingAdapter(),
      simctlAdapterFactory: (deviceId) => _FakeRecordingAdapter(),
      linuxAdapterFactory: (appId, {processId}) {
        capturedAppId = appId;
        capturedProcessId = processId;
        return _FakeRecordingAdapter();
      },
    );

    final resolution = resolver.resolveDetailed(
      platform: 'linux',
      recording: autoRequest,
      client: CockpitRemoteSessionClient(
        baseUri: Uri.parse('http://127.0.0.1:47331'),
      ),
      platformAppId: 'cockpit_demo',
      processId: 5101,
    );

    expect(resolution?.implementation, 'linuxHost');
    expect(resolution?.effectiveLayer, CockpitRecordingLayer.hostScreen);
    expect(resolution?.fallbackUsed, isFalse);
    expect(capturedAppId, 'cockpit_demo');
    expect(capturedProcessId, 5101);
  });

  test(
    'uses process-scoped host recording for Linux full mode when only a process id is available',
    () {
      String? capturedAppId;
      int? capturedProcessId;
      final resolver = CockpitRecordingStrategyResolver(
        remoteAdapterFactory: (client) => _FakeRecordingAdapter(),
        adbAdapterFactory: (deviceId) => _FakeRecordingAdapter(),
        simctlAdapterFactory: (deviceId) => _FakeRecordingAdapter(),
        linuxAdapterFactory: (appId, {processId}) {
          capturedAppId = appId;
          capturedProcessId = processId;
          return _FakeRecordingAdapter();
        },
      );

      final resolution = resolver.resolveDetailed(
        platform: 'linux',
        recording: fullRequest,
        client: CockpitRemoteSessionClient(
          baseUri: Uri.parse('http://127.0.0.1:47331'),
        ),
        sessionHandle: CockpitRemoteSessionHandle(
          platform: 'linux',
          deviceId: 'linux',
          projectDir: '/workspace/examples/cockpit_demo',
          target: 'cockpit/main.dart',
          appId: 'app-with-unknown-platform-id',
          platformAppIdKnown: false,
          processId: 5101,
          host: '127.0.0.1',
          hostPort: 47331,
          devicePort: 47331,
          baseUrl: 'http://127.0.0.1:47331',
          launchedAt: DateTime.utc(2026, 3, 24),
        ),
      );

      expect(resolution?.implementation, 'linuxHost');
      expect(resolution?.effectiveLayer, CockpitRecordingLayer.hostScreen);
      expect(resolution?.fallbackUsed, isFalse);
      expect(capturedAppId, 'pid-5101');
      expect(capturedProcessId, 5101);
    },
  );

  test(
    'falls back to app-window recording when macOS system-layer recording is requested with fallback enabled',
    () {
      final resolver = CockpitRecordingStrategyResolver(
        remoteAdapterFactory: (client) => _FakeRecordingAdapter(),
        adbAdapterFactory: (deviceId) => _FakeRecordingAdapter(),
        simctlAdapterFactory: (deviceId) => _FakeRecordingAdapter(),
      );

      final resolution = resolver.resolveDetailed(
        platform: 'macos',
        recording: fallbackSystemLayerRequest,
        client: CockpitRemoteSessionClient(
          baseUri: Uri.parse('http://127.0.0.1:47331'),
        ),
      );

      expect(resolution?.implementation, 'remote');
      expect(resolution?.effectiveLayer, CockpitRecordingLayer.appWindow);
      expect(resolution?.fallbackUsed, isTrue);
      expect(resolution?.fallbackReason, contains('system'));
    },
  );

  test(
    'reports unsupported flutter-layer recording when fallback is disabled',
    () {
      final resolver = CockpitRecordingStrategyResolver(
        remoteAdapterFactory: (client) => _FakeRecordingAdapter(),
        adbAdapterFactory: (deviceId) => _FakeRecordingAdapter(),
        simctlAdapterFactory: (deviceId) => _FakeRecordingAdapter(),
      );

      final resolution = resolver.resolveDetailed(
        platform: 'ios',
        recording: strictFlutterLayerRequest,
        client: CockpitRemoteSessionClient(
          baseUri: Uri.parse('http://127.0.0.1:47331'),
        ),
      );

      expect(resolution?.adapter, isNull);
      expect(resolution?.unsupportedReason, contains('flutter'));
    },
  );

  test('returns null when the script does not request recording', () {
    final resolver = CockpitRecordingStrategyResolver(
      remoteAdapterFactory: (client) => _FakeRecordingAdapter(),
      adbAdapterFactory: (deviceId) => _FakeRecordingAdapter(),
      simctlAdapterFactory: (deviceId) => _FakeRecordingAdapter(),
      macosAdapterFactory: (appId) => _FakeRecordingAdapter(),
    );

    final resolution = resolver.resolveDetailed(
      platform: 'android',
      recording: null,
      client: CockpitRemoteSessionClient(
        baseUri: Uri.parse('http://127.0.0.1:47331'),
      ),
      androidDeviceId: 'emulator-5554',
    );

    expect(resolution, isNull);
  });

  test(
    'prefers an active macOS host recording session when stop flow requests active host reuse',
    () {
      addTearDown(() {
        cockpitClearActiveHostRecordingSession(
          'macos:dev.cockpit.cockpitDemo.session',
        );
      });
      cockpitStoreActiveHostRecordingSession(
        'macos:dev.cockpit.cockpitDemo.session',
        CockpitHostRecordingRuntimeSession(
          process: _FakeProcess(),
          request: autoRequest,
          outputFile: File('/tmp/active-recording.mp4'),
          stderrSubscription: null,
          stopwatch: Stopwatch(),
        ),
      );

      final resolver = CockpitRecordingStrategyResolver(
        remoteAdapterFactory: (client) => _FakeRecordingAdapter(),
        adbAdapterFactory: (deviceId) => _FakeRecordingAdapter(),
        simctlAdapterFactory: (deviceId) => _FakeRecordingAdapter(),
        macosAdapterFactory: (appId) => _FakeRecordingAdapter(),
      );

      final resolution = resolver.resolveDetailed(
        platform: 'macos',
        recording: autoRequest,
        client: CockpitRemoteSessionClient(
          baseUri: Uri.parse('http://127.0.0.1:47331'),
        ),
        sessionHandle: CockpitRemoteSessionHandle(
          platform: 'macos',
          deviceId: 'macos',
          projectDir: '/workspace/examples/cockpit_demo',
          target: 'cockpit/main.dart',
          appId: 'dev.cockpit.cockpitDemo.session',
          host: '127.0.0.1',
          hostPort: 47331,
          devicePort: 47331,
          baseUrl: 'http://127.0.0.1:47331',
          launchedAt: DateTime.utc(2026, 4, 13),
        ),
        preferActiveHostSession: true,
      );

      expect(resolution?.implementation, 'macosHost');
      expect(resolution?.effectiveLayer, CockpitRecordingLayer.hostScreen);
    },
  );

  test(
    'falls back to remote stop when a persisted macOS host recording session is stale',
    () async {
      const sessionKey = 'macos:dev.cockpit.staleHost';
      addTearDown(() {
        cockpitClearPersistedHostRecordingSession(sessionKey);
      });
      await cockpitPersistHostRecordingSession(
        sessionKey,
        CockpitHostRecordingPersistedSession(
          pid: 999999,
          request: autoRequest,
          outputFilePath: '/tmp/stale-host-recording.mp4',
          startedAt: DateTime.utc(2026, 4, 13),
        ),
      );

      final resolver = CockpitRecordingStrategyResolver(
        remoteAdapterFactory: (client) => _FakeRecordingAdapter(),
        adbAdapterFactory: (deviceId) => _FakeRecordingAdapter(),
        simctlAdapterFactory: (deviceId) => _FakeRecordingAdapter(),
        macosAdapterFactory: (appId) => _FakeRecordingAdapter(),
      );

      final resolution = await resolver.resolveDetailedForStop(
        platform: 'macos',
        recording: autoRequest,
        client: CockpitRemoteSessionClient(
          baseUri: Uri.parse('http://127.0.0.1:47331'),
        ),
        sessionHandle: CockpitRemoteSessionHandle(
          platform: 'macos',
          deviceId: 'macos',
          projectDir: '/workspace/examples/cockpit_demo',
          target: 'cockpit/main.dart',
          appId: 'dev.cockpit.staleHost',
          host: '127.0.0.1',
          hostPort: 47331,
          devicePort: 47331,
          baseUrl: 'http://127.0.0.1:47331',
          launchedAt: DateTime.utc(2026, 4, 13),
        ),
      );

      expect(resolution?.implementation, 'remote');
      expect(resolution?.effectiveLayer, CockpitRecordingLayer.appWindow);
      expect(cockpitReadPersistedHostRecordingSession(sessionKey), isNull);
    },
  );
}

final class _FakeRecordingAdapter implements CockpitRecordingAdapter {
  @override
  Future<CockpitRecordingSession> startRecording(
    CockpitRecordingRequest request,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<CockpitRecordingResult> stopRecording() {
    throw UnimplementedError();
  }
}

final class _FakeProcess implements Process {
  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) => true;

  @override
  Future<int> get exitCode async => 0;

  @override
  int get pid => 1;

  @override
  IOSink get stdin => throw UnimplementedError();

  @override
  Stream<List<int>> get stderr => const Stream<List<int>>.empty();

  @override
  Stream<List<int>> get stdout => const Stream<List<int>>.empty();
}
