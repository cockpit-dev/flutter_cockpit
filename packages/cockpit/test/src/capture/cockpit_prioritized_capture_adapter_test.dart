import 'dart:convert';
import 'dart:io';

import 'package:cockpit_protocol/cockpit_protocol.dart';
import 'package:cockpit/src/adapters/cockpit_capture_adapter.dart';
import 'package:cockpit/src/application/cockpit_application_service_exception.dart';
import 'package:cockpit/src/capture/cockpit_prioritized_capture_adapter.dart';
import 'package:cockpit/src/remote/cockpit_remote_session_client.dart';
import 'package:test/test.dart';

void main() {
  test(
    'uses host capture for acceptance screenshots and merges snapshot data',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      var waitForUiIdleCount = 0;
      server.listen((request) async {
        request.response.headers.contentType = ContentType.json;
        if (request.uri.path == '/commands/execute') {
          final payload =
              jsonDecode(await utf8.decoder.bind(request).join())
                  as Map<String, Object?>;
          expect(payload['commandType'], 'waitForUiIdle');
          waitForUiIdleCount += 1;
          request.response.write(
            jsonEncode(
              CockpitCommandResult(
                success: true,
                commandId: payload['commandId']! as String,
                commandType: CockpitCommandType.waitForUiIdle,
                durationMs: 12,
              ).toJson(),
            ),
          );
        } else if (request.uri.path == '/snapshot') {
          expect(request.uri.queryParameters['profile'], 'investigate');
          expect(
            request.uri.queryParameters['includeAccessibilitySummary'],
            'true',
          );
          request.response.write(
            jsonEncode(
              CockpitSnapshot(
                routeName: '/inbox',
                visibleTargets: <CockpitSnapshotTarget>[
                  CockpitSnapshotTarget(
                    registrationId: 'native.inbox.text.inbox-title',
                    text: 'Inbox',
                    typeName: 'Text',
                    routeName: '/inbox',
                  ),
                ],
                diagnosticLevel: CockpitSnapshotProfile.investigate,
              ).toJson(),
            ),
          );
        } else {
          request.response.statusCode = HttpStatus.notFound;
          request.response.write('{}');
        }
        await request.response.close();
      });

      final remoteAdapter = _FakeCaptureAdapter(
        execution: CockpitCommandExecution(
          result: CockpitCommandResult(
            success: true,
            commandId: 'capture',
            commandType: CockpitCommandType.captureScreenshot,
            durationMs: 10,
            artifacts: const <CockpitArtifactRef>[
              CockpitArtifactRef(
                role: 'screenshot',
                relativePath: 'screenshots/remote.png',
              ),
            ],
          ),
        ),
      );
      final hostAdapter = _FakeCaptureAdapter(
        execution: CockpitCommandExecution(
          result: CockpitCommandResult(
            success: true,
            commandId: 'capture',
            commandType: CockpitCommandType.captureScreenshot,
            durationMs: 12,
            artifacts: const <CockpitArtifactRef>[
              CockpitArtifactRef(
                role: 'screenshot',
                relativePath: 'screenshots/host.png',
              ),
            ],
            requestedCaptureProfile: CockpitCaptureProfile.acceptance,
            resolvedCaptureKind: CockpitCaptureKind.nativeAcceptance,
          ),
          artifactSourcePaths: const <String, String>{
            'screenshots/host.png': '/tmp/host.png',
          },
        ),
      );
      final adapter = CockpitPrioritizedCaptureAdapter(
        remoteAdapter: remoteAdapter,
        hostAcceptanceAdapter: hostAdapter,
        client: CockpitRemoteSessionClient(
          baseUri: Uri.parse('http://127.0.0.1:${server.port}'),
        ),
      );

      final execution = await adapter.capture(
        CockpitCommand(
          commandId: 'capture',
          commandType: CockpitCommandType.captureScreenshot,
          screenshotRequest: const CockpitScreenshotRequest(
            reason: CockpitScreenshotReason.acceptance,
            name: 'acceptance',
            includeSnapshot: true,
            attachToStep: true,
          ),
        ),
      );

      expect(hostAdapter.captureCount, 1);
      expect(remoteAdapter.captureCount, 0);
      expect(waitForUiIdleCount, 1);
      expect(
        execution.result.artifacts.single.relativePath,
        'screenshots/host.png',
      );
      expect(execution.result.snapshot?['routeName'], '/inbox');
      expect(execution.result.snapshot?['diagnosticLevel'], 'investigate');
      expect(
        execution.artifactSourcePaths['screenshots/host.png'],
        '/tmp/host.png',
      );
    },
  );

  test('uses app capture first for non-acceptance screenshots', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      request.response.headers.contentType = ContentType.json;
      if (request.uri.path == '/commands/execute') {
        request.response.write(
          jsonEncode(
            CockpitCommandResult(
              success: true,
              commandId: 'wait-for-idle',
              commandType: CockpitCommandType.waitForUiIdle,
              durationMs: 5,
            ).toJson(),
          ),
        );
      } else {
        request.response.statusCode = HttpStatus.notFound;
        request.response.write('{}');
      }
      await request.response.close();
    });

    final remoteAdapter = _FakeCaptureAdapter(
      execution: CockpitCommandExecution(
        result: CockpitCommandResult(
          success: true,
          commandId: 'capture',
          commandType: CockpitCommandType.captureScreenshot,
          durationMs: 8,
          artifacts: const <CockpitArtifactRef>[
            CockpitArtifactRef(
              role: 'screenshot',
              relativePath: 'screenshots/remote_after_action.png',
            ),
          ],
        ),
      ),
    );
    final hostAdapter = _FakeCaptureAdapter(
      execution: CockpitCommandExecution(
        result: CockpitCommandResult(
          success: true,
          commandId: 'capture',
          commandType: CockpitCommandType.captureScreenshot,
          durationMs: 8,
          artifacts: const <CockpitArtifactRef>[
            CockpitArtifactRef(
              role: 'screenshot',
              relativePath: 'screenshots/host_after_action.png',
            ),
          ],
          requestedCaptureProfile: CockpitCaptureProfile.diagnostic,
          resolvedCaptureKind: CockpitCaptureKind.nativeAcceptance,
        ),
      ),
    );
    final adapter = CockpitPrioritizedCaptureAdapter(
      remoteAdapter: remoteAdapter,
      hostAcceptanceAdapter: hostAdapter,
      client: CockpitRemoteSessionClient(
        baseUri: Uri.parse('http://127.0.0.1:${server.port}'),
      ),
    );

    final execution = await adapter.capture(
      CockpitCommand(
        commandId: 'capture',
        commandType: CockpitCommandType.captureScreenshot,
        screenshotRequest: const CockpitScreenshotRequest(
          reason: CockpitScreenshotReason.afterAction,
          name: 'after-action',
        ),
      ),
    );

    expect(remoteAdapter.captureCount, 1);
    expect(hostAdapter.captureCount, 0);
    expect(
      execution.result.artifacts.single.relativePath,
      'screenshots/remote_after_action.png',
    );
  });

  test('uses app capture first for desktop acceptance policy', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode(
          CockpitCommandResult(
            success: true,
            commandId: 'wait-for-idle',
            commandType: CockpitCommandType.waitForUiIdle,
            durationMs: 5,
          ).toJson(),
        ),
      );
      await request.response.close();
    });

    final remoteAdapter = _FakeCaptureAdapter(
      execution: _successfulCapture(
        path: 'screenshots/app_acceptance.png',
        kind: CockpitCaptureKind.appNative,
      ),
    );
    final hostAdapter = _FakeCaptureAdapter(
      execution: _successfulCapture(
        path: 'screenshots/host_acceptance.png',
        kind: CockpitCaptureKind.hostSystem,
      ),
    );
    final adapter = CockpitPrioritizedCaptureAdapter(
      remoteAdapter: remoteAdapter,
      hostAcceptanceAdapter: hostAdapter,
      client: CockpitRemoteSessionClient(
        baseUri: Uri.parse('http://127.0.0.1:${server.port}'),
      ),
      preferHostForAcceptance: false,
    );

    final execution = await adapter.capture(
      CockpitCommand(
        commandId: 'capture',
        commandType: CockpitCommandType.captureScreenshot,
        screenshotRequest: const CockpitScreenshotRequest(
          reason: CockpitScreenshotReason.acceptance,
          name: 'acceptance',
        ),
      ),
    );

    expect(remoteAdapter.captureCount, 1);
    expect(hostAdapter.captureCount, 0);
    expect(execution.result.resolvedCaptureKind, CockpitCaptureKind.appNative);
  });

  test('keeps capture running when best-effort idle wait fails', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      request.response.statusCode = HttpStatus.internalServerError;
      request.response.write('{}');
      await request.response.close();
    });

    final remoteAdapter = _FakeCaptureAdapter(
      execution: _successfulCapture(
        path: 'screenshots/app_acceptance.png',
        kind: CockpitCaptureKind.appNative,
      ),
    );
    final hostAdapter = _FakeCaptureAdapter(
      execution: _successfulCapture(
        path: 'screenshots/host_acceptance.png',
        kind: CockpitCaptureKind.hostSystem,
      ),
    );
    final adapter = CockpitPrioritizedCaptureAdapter(
      remoteAdapter: remoteAdapter,
      hostAcceptanceAdapter: hostAdapter,
      client: CockpitRemoteSessionClient(
        baseUri: Uri.parse('http://127.0.0.1:${server.port}'),
      ),
    );

    final execution = await adapter.capture(
      CockpitCommand(
        commandId: 'capture',
        commandType: CockpitCommandType.captureScreenshot,
        screenshotRequest: const CockpitScreenshotRequest(
          reason: CockpitScreenshotReason.acceptance,
          name: 'acceptance',
        ),
      ),
    );

    expect(execution.result.success, isTrue);
    expect(hostAdapter.captureCount, 1);
    expect(remoteAdapter.captureCount, 0);
  });

  test(
    'falls back to remote capture when host acceptance capture fails',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((request) async {
        request.response.headers.contentType = ContentType.json;
        if (request.uri.path == '/commands/execute') {
          request.response.write(
            jsonEncode(
              CockpitCommandResult(
                success: true,
                commandId: 'wait-for-idle',
                commandType: CockpitCommandType.waitForUiIdle,
                durationMs: 5,
              ).toJson(),
            ),
          );
        } else if (request.uri.path == '/health') {
          request.response.write(
            jsonEncode(
              CockpitRemoteSessionStatus(
                sessionId: 'app-session',
                platform: 'macos',
                transportType: 'remoteHttp',
                currentRouteName: '/inbox',
                capabilities: CockpitCapabilities(
                  platform: 'macos',
                  transportType: 'remoteHttp',
                  supportsInAppControl: true,
                  supportsFlutterViewCapture: true,
                  supportsNativeScreenCapture: false,
                  supportsHostAutomation: false,
                  supportedCommands: const <CockpitCommandType>[
                    CockpitCommandType.captureScreenshot,
                    CockpitCommandType.waitForUiIdle,
                  ],
                ),
                recordingCapabilities: CockpitRecordingCapabilities(
                  supportsNativeRecording: false,
                ),
                snapshot: CockpitSnapshot(routeName: '/inbox'),
              ).toJson(),
            ),
          );
        } else {
          request.response.statusCode = HttpStatus.notFound;
          request.response.write('{}');
        }
        await request.response.close();
      });

      final remoteAdapter = _FakeCaptureAdapter(
        execution: CockpitCommandExecution(
          result: CockpitCommandResult(
            success: true,
            commandId: 'capture',
            commandType: CockpitCommandType.captureScreenshot,
            durationMs: 9,
            artifacts: const <CockpitArtifactRef>[
              CockpitArtifactRef(
                role: 'screenshot',
                relativePath: 'screenshots/remote_acceptance.png',
              ),
            ],
            requestedCaptureProfile: CockpitCaptureProfile.acceptance,
            resolvedCaptureKind: CockpitCaptureKind.flutterView,
          ),
          artifactSourcePaths: const <String, String>{
            'screenshots/remote_acceptance.png': '/tmp/remote_acceptance.png',
          },
        ),
      );
      final hostAdapter = _FakeCaptureAdapter(
        execution: CockpitCommandExecution(
          result: CockpitCommandResult(
            success: false,
            commandId: 'capture',
            commandType: CockpitCommandType.captureScreenshot,
            durationMs: 12,
            requestedCaptureProfile: CockpitCaptureProfile.acceptance,
            error: CockpitCommandError.captureFailed(
              message: 'macOS screencapture failed.',
            ),
          ),
        ),
      );

      final adapter = CockpitPrioritizedCaptureAdapter(
        remoteAdapter: remoteAdapter,
        hostAcceptanceAdapter: hostAdapter,
        client: CockpitRemoteSessionClient(
          baseUri: Uri.parse('http://127.0.0.1:${server.port}'),
        ),
      );

      final execution = await adapter.capture(
        CockpitCommand(
          commandId: 'capture',
          commandType: CockpitCommandType.captureScreenshot,
          screenshotRequest: const CockpitScreenshotRequest(
            reason: CockpitScreenshotReason.acceptance,
            name: 'acceptance',
            includeSnapshot: false,
            attachToStep: true,
          ),
        ),
      );

      expect(hostAdapter.captureCount, 1);
      expect(remoteAdapter.captureCount, 1);
      expect(
        execution.result.artifacts.single.relativePath,
        'screenshots/remote_acceptance.png',
      );
      expect(execution.result.usedCaptureFallback, isTrue);
      expect(execution.result.degradationReason, 'hostCaptureFailed');
    },
  );

  test('preserves nested app fallback metadata after host failure', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode(
          CockpitCommandResult(
            success: true,
            commandId: 'wait-for-idle',
            commandType: CockpitCommandType.waitForUiIdle,
            durationMs: 2,
          ).toJson(),
        ),
      );
      await request.response.close();
    });

    final hostAdapter = _FakeCaptureAdapter(
      execution: CockpitCommandExecution(
        result: CockpitCommandResult(
          success: false,
          commandId: 'capture',
          commandType: CockpitCommandType.captureScreenshot,
          durationMs: 3,
          error: CockpitCommandError.captureFailed(
            message: 'host capture failed',
          ),
        ),
      ),
    );
    final remoteAdapter = _FakeCaptureAdapter(
      execution: CockpitCommandExecution(
        result: CockpitCommandResult(
          success: true,
          commandId: 'capture',
          commandType: CockpitCommandType.captureScreenshot,
          durationMs: 4,
          resolvedCaptureKind: CockpitCaptureKind.flutterView,
          usedCaptureFallback: true,
          degradationReason: 'nativeCaptureUnavailable',
        ),
      ),
    );
    final adapter = CockpitPrioritizedCaptureAdapter(
      remoteAdapter: remoteAdapter,
      hostAcceptanceAdapter: hostAdapter,
      client: CockpitRemoteSessionClient(
        baseUri: Uri.parse('http://127.0.0.1:${server.port}'),
      ),
    );

    final execution = await adapter.capture(
      CockpitCommand(
        commandId: 'capture',
        commandType: CockpitCommandType.captureScreenshot,
        screenshotRequest: const CockpitScreenshotRequest(
          reason: CockpitScreenshotReason.acceptance,
          name: 'acceptance',
        ),
      ),
    );

    expect(execution.result.success, isTrue);
    expect(
      execution.result.degradationReason,
      'hostCaptureFailed; nativeCaptureUnavailable',
    );
  });

  test(
    'tries app fallback when cached capabilities omit screenshot support',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((request) async {
        request.response.headers.contentType = ContentType.json;
        if (request.uri.path == '/commands/execute') {
          request.response.write(
            jsonEncode(
              CockpitCommandResult(
                success: true,
                commandId: 'wait-for-idle',
                commandType: CockpitCommandType.waitForUiIdle,
                durationMs: 5,
              ).toJson(),
            ),
          );
        } else if (request.uri.path == '/health') {
          request.response.write(
            jsonEncode(
              CockpitRemoteSessionStatus(
                sessionId: 'web-session',
                platform: 'web',
                transportType: 'remoteHttp',
                currentRouteName: '/inbox',
                capabilities: CockpitCapabilities(
                  platform: 'web',
                  transportType: 'remoteHttp',
                  supportsInAppControl: true,
                  supportsFlutterViewCapture: false,
                  supportsNativeScreenCapture: false,
                  supportsHostAutomation: false,
                  supportedCommands: const <CockpitCommandType>[
                    CockpitCommandType.tap,
                    CockpitCommandType.waitForUiIdle,
                  ],
                ),
                recordingCapabilities: CockpitRecordingCapabilities(
                  supportsNativeRecording: false,
                ),
                snapshot: CockpitSnapshot(routeName: '/inbox'),
              ).toJson(),
            ),
          );
        } else {
          request.response.statusCode = HttpStatus.notFound;
          request.response.write('{}');
        }
        await request.response.close();
      });

      final remoteAdapter = _FakeCaptureAdapter(
        execution: CockpitCommandExecution(
          result: CockpitCommandResult(
            success: true,
            commandId: 'capture',
            commandType: CockpitCommandType.captureScreenshot,
            durationMs: 9,
            artifacts: const <CockpitArtifactRef>[
              CockpitArtifactRef(
                role: 'screenshot',
                relativePath: 'screenshots/remote_acceptance.png',
              ),
            ],
            requestedCaptureProfile: CockpitCaptureProfile.acceptance,
            resolvedCaptureKind: CockpitCaptureKind.flutterView,
          ),
        ),
      );
      final hostAdapter = _FakeCaptureAdapter(
        execution: CockpitCommandExecution(
          result: CockpitCommandResult(
            success: false,
            commandId: 'capture',
            commandType: CockpitCommandType.captureScreenshot,
            durationMs: 12,
            requestedCaptureProfile: CockpitCaptureProfile.acceptance,
            error: CockpitCommandError.captureFailed(
              message: 'macOS screencapture failed.',
            ),
          ),
        ),
      );

      final adapter = CockpitPrioritizedCaptureAdapter(
        remoteAdapter: remoteAdapter,
        hostAcceptanceAdapter: hostAdapter,
        client: CockpitRemoteSessionClient(
          baseUri: Uri.parse('http://127.0.0.1:${server.port}'),
        ),
      );

      final execution = await adapter.capture(
        CockpitCommand(
          commandId: 'capture',
          commandType: CockpitCommandType.captureScreenshot,
          screenshotRequest: const CockpitScreenshotRequest(
            reason: CockpitScreenshotReason.acceptance,
            name: 'acceptance',
            includeSnapshot: false,
            attachToStep: true,
          ),
        ),
      );

      expect(hostAdapter.captureCount, 1);
      expect(remoteAdapter.captureCount, 1);
      expect(execution.result.success, isTrue);
      expect(execution.result.usedCaptureFallback, isTrue);
      expect(execution.result.degradationReason, 'hostCaptureFailed');
    },
  );

  test(
    'does not gate app fallback on a native-only capability snapshot',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((request) async {
        request.response.headers.contentType = ContentType.json;
        if (request.uri.path == '/commands/execute') {
          request.response.write(
            jsonEncode(
              CockpitCommandResult(
                success: true,
                commandId: 'wait-for-idle',
                commandType: CockpitCommandType.waitForUiIdle,
                durationMs: 5,
              ).toJson(),
            ),
          );
        } else if (request.uri.path == '/health') {
          request.response.write(
            jsonEncode(
              CockpitRemoteSessionStatus(
                sessionId: 'web-session',
                platform: 'web',
                transportType: 'remoteHttp',
                currentRouteName: '/inbox',
                capabilities: CockpitCapabilities(
                  platform: 'web',
                  transportType: 'remoteHttp',
                  supportsInAppControl: true,
                  supportsFlutterViewCapture: false,
                  supportsNativeScreenCapture: true,
                  supportsHostAutomation: true,
                  supportedCommands: const <CockpitCommandType>[
                    CockpitCommandType.tap,
                    CockpitCommandType.waitForUiIdle,
                  ],
                ),
                recordingCapabilities: CockpitRecordingCapabilities(
                  supportsNativeRecording: true,
                ),
                snapshot: CockpitSnapshot(routeName: '/inbox'),
              ).toJson(),
            ),
          );
        } else {
          request.response.statusCode = HttpStatus.notFound;
          request.response.write('{}');
        }
        await request.response.close();
      });

      final remoteAdapter = _FakeCaptureAdapter(
        execution: CockpitCommandExecution(
          result: CockpitCommandResult(
            success: true,
            commandId: 'capture',
            commandType: CockpitCommandType.captureScreenshot,
            durationMs: 9,
            artifacts: const <CockpitArtifactRef>[
              CockpitArtifactRef(
                role: 'screenshot',
                relativePath: 'screenshots/remote_acceptance.png',
              ),
            ],
            requestedCaptureProfile: CockpitCaptureProfile.acceptance,
            resolvedCaptureKind: CockpitCaptureKind.flutterView,
          ),
        ),
      );
      final hostAdapter = _FakeCaptureAdapter(
        execution: CockpitCommandExecution(
          result: CockpitCommandResult(
            success: false,
            commandId: 'capture',
            commandType: CockpitCommandType.captureScreenshot,
            durationMs: 12,
            requestedCaptureProfile: CockpitCaptureProfile.acceptance,
            error: CockpitCommandError.captureFailed(
              message: 'host capture failed',
            ),
          ),
        ),
      );

      final adapter = CockpitPrioritizedCaptureAdapter(
        remoteAdapter: remoteAdapter,
        hostAcceptanceAdapter: hostAdapter,
        client: CockpitRemoteSessionClient(
          baseUri: Uri.parse('http://127.0.0.1:${server.port}'),
        ),
      );

      final execution = await adapter.capture(
        CockpitCommand(
          commandId: 'capture',
          commandType: CockpitCommandType.captureScreenshot,
          screenshotRequest: const CockpitScreenshotRequest(
            reason: CockpitScreenshotReason.acceptance,
            name: 'acceptance',
          ),
        ),
      );

      expect(hostAdapter.captureCount, 1);
      expect(remoteAdapter.captureCount, 1);
      expect(execution.result.success, isTrue);
      expect(execution.result.usedCaptureFallback, isTrue);
      expect(execution.result.degradationReason, 'hostCaptureFailed');
    },
  );

  test(
    'falls back to app capture when remote capabilities cannot be read',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((request) async {
        request.response.headers.contentType = ContentType.json;
        if (request.uri.path == '/commands/execute') {
          request.response.write(
            jsonEncode(
              CockpitCommandResult(
                success: true,
                commandId: 'wait-for-idle',
                commandType: CockpitCommandType.waitForUiIdle,
                durationMs: 5,
              ).toJson(),
            ),
          );
        } else if (request.uri.path == '/health') {
          request.response.statusCode = HttpStatus.internalServerError;
          request.response.write(
            jsonEncode(<String, Object?>{'error': 'health unavailable'}),
          );
        } else {
          request.response.statusCode = HttpStatus.notFound;
          request.response.write('{}');
        }
        await request.response.close();
      });

      final remoteAdapter = _FakeCaptureAdapter(
        execution: CockpitCommandExecution(
          result: CockpitCommandResult(
            success: true,
            commandId: 'capture',
            commandType: CockpitCommandType.captureScreenshot,
            durationMs: 9,
            artifacts: const <CockpitArtifactRef>[
              CockpitArtifactRef(
                role: 'screenshot',
                relativePath: 'screenshots/remote_acceptance.png',
              ),
            ],
            requestedCaptureProfile: CockpitCaptureProfile.acceptance,
            resolvedCaptureKind: CockpitCaptureKind.flutterView,
          ),
        ),
      );
      final hostAdapter = _FakeCaptureAdapter(
        execution: CockpitCommandExecution(
          result: CockpitCommandResult(
            success: false,
            commandId: 'capture',
            commandType: CockpitCommandType.captureScreenshot,
            durationMs: 12,
            requestedCaptureProfile: CockpitCaptureProfile.acceptance,
            error: CockpitCommandError.captureFailed(
              message: 'host capture failed',
            ),
          ),
        ),
      );

      final adapter = CockpitPrioritizedCaptureAdapter(
        remoteAdapter: remoteAdapter,
        hostAcceptanceAdapter: hostAdapter,
        client: CockpitRemoteSessionClient(
          baseUri: Uri.parse('http://127.0.0.1:${server.port}'),
        ),
      );

      final execution = await adapter.capture(
        CockpitCommand(
          commandId: 'capture',
          commandType: CockpitCommandType.captureScreenshot,
          screenshotRequest: const CockpitScreenshotRequest(
            reason: CockpitScreenshotReason.acceptance,
            name: 'acceptance',
          ),
        ),
      );

      expect(hostAdapter.captureCount, 1);
      expect(remoteAdapter.captureCount, 1);
      expect(execution.result.success, isTrue);
      expect(execution.result.usedCaptureFallback, isTrue);
      expect(execution.result.degradationReason, 'hostCaptureFailed');
    },
  );

  test('does not execute fallback when the request is strict', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode(
          CockpitCommandResult(
            success: true,
            commandId: 'wait-for-idle',
            commandType: CockpitCommandType.waitForUiIdle,
            durationMs: 5,
          ).toJson(),
        ),
      );
      await request.response.close();
    });

    final remoteAdapter = _FakeCaptureAdapter(
      execution: _successfulCapture(
        path: 'screenshots/app_acceptance.png',
        kind: CockpitCaptureKind.appNative,
      ),
    );
    final hostAdapter = _FakeCaptureAdapter(
      execution: CockpitCommandExecution(
        result: CockpitCommandResult(
          success: false,
          commandId: 'capture',
          commandType: CockpitCommandType.captureScreenshot,
          durationMs: 4,
          error: CockpitCommandError.captureFailed(
            message: 'host capture failed',
          ),
        ),
      ),
    );
    final adapter = CockpitPrioritizedCaptureAdapter(
      remoteAdapter: remoteAdapter,
      hostAcceptanceAdapter: hostAdapter,
      client: CockpitRemoteSessionClient(
        baseUri: Uri.parse('http://127.0.0.1:${server.port}'),
      ),
    );

    final execution = await adapter.capture(
      CockpitCommand(
        commandId: 'capture',
        commandType: CockpitCommandType.captureScreenshot,
        screenshotRequest: const CockpitScreenshotRequest(
          reason: CockpitScreenshotReason.acceptance,
          name: 'acceptance',
          allowFallback: false,
        ),
      ),
    );

    expect(execution.result.success, isFalse);
    expect(hostAdapter.captureCount, 1);
    expect(remoteAdapter.captureCount, 0);
  });

  test(
    'keeps host failure when advertised remote screenshot fallback throws',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((request) async {
        request.response.headers.contentType = ContentType.json;
        if (request.uri.path == '/commands/execute') {
          request.response.write(
            jsonEncode(
              CockpitCommandResult(
                success: true,
                commandId: 'wait-for-idle',
                commandType: CockpitCommandType.waitForUiIdle,
                durationMs: 5,
              ).toJson(),
            ),
          );
        } else if (request.uri.path == '/health') {
          request.response.write(
            jsonEncode(
              CockpitRemoteSessionStatus(
                sessionId: 'web-session',
                platform: 'web',
                transportType: 'remoteHttp',
                currentRouteName: '/inbox',
                capabilities: CockpitCapabilities(
                  platform: 'web',
                  transportType: 'remoteHttp',
                  supportsInAppControl: true,
                  supportsFlutterViewCapture: true,
                  supportsNativeScreenCapture: false,
                  supportsHostAutomation: false,
                  supportedCommands: const <CockpitCommandType>[
                    CockpitCommandType.captureScreenshot,
                    CockpitCommandType.waitForUiIdle,
                  ],
                ),
                recordingCapabilities: CockpitRecordingCapabilities(
                  supportsNativeRecording: false,
                ),
                snapshot: CockpitSnapshot(routeName: '/inbox'),
              ).toJson(),
            ),
          );
        } else {
          request.response.statusCode = HttpStatus.notFound;
          request.response.write('{}');
        }
        await request.response.close();
      });

      final remoteAdapter = _ThrowingCaptureAdapter(
        const CockpitApplicationServiceException(
          code: 'serverError',
          message: 'No in-app handler registered for captureScreenshot',
        ),
      );
      final hostAdapter = _FakeCaptureAdapter(
        execution: CockpitCommandExecution(
          result: CockpitCommandResult(
            success: false,
            commandId: 'capture',
            commandType: CockpitCommandType.captureScreenshot,
            durationMs: 12,
            requestedCaptureProfile: CockpitCaptureProfile.acceptance,
            error: CockpitCommandError.captureFailed(
              message: 'host screenshot capture failed',
            ),
          ),
        ),
      );

      final adapter = CockpitPrioritizedCaptureAdapter(
        remoteAdapter: remoteAdapter,
        hostAcceptanceAdapter: hostAdapter,
        client: CockpitRemoteSessionClient(
          baseUri: Uri.parse('http://127.0.0.1:${server.port}'),
        ),
      );

      final execution = await adapter.capture(
        CockpitCommand(
          commandId: 'capture',
          commandType: CockpitCommandType.captureScreenshot,
          screenshotRequest: const CockpitScreenshotRequest(
            reason: CockpitScreenshotReason.acceptance,
            name: 'acceptance',
          ),
        ),
      );

      expect(hostAdapter.captureCount, 1);
      expect(remoteAdapter.captureCount, 1);
      expect(execution.result.success, isFalse);
      expect(execution.result.error?.message, 'host screenshot capture failed');
      expect(execution.result.usedCaptureFallback, isTrue);
      expect(execution.result.degradationReason, contains('appFallbackThrew'));
      expect(
        execution.result.degradationReason,
        contains('No in-app handler registered for captureScreenshot'),
      );
    },
  );

  test(
    'keeps host failure when advertised remote screenshot fallback fails',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((request) async {
        request.response.headers.contentType = ContentType.json;
        if (request.uri.path == '/commands/execute') {
          request.response.write(
            jsonEncode(
              CockpitCommandResult(
                success: true,
                commandId: 'wait-for-idle',
                commandType: CockpitCommandType.waitForUiIdle,
                durationMs: 5,
              ).toJson(),
            ),
          );
        } else if (request.uri.path == '/health') {
          request.response.write(
            jsonEncode(
              CockpitRemoteSessionStatus(
                sessionId: 'web-session',
                platform: 'web',
                transportType: 'remoteHttp',
                currentRouteName: '/inbox',
                capabilities: CockpitCapabilities(
                  platform: 'web',
                  transportType: 'remoteHttp',
                  supportsInAppControl: true,
                  supportsFlutterViewCapture: true,
                  supportsNativeScreenCapture: false,
                  supportsHostAutomation: false,
                  supportedCommands: const <CockpitCommandType>[
                    CockpitCommandType.captureScreenshot,
                    CockpitCommandType.waitForUiIdle,
                  ],
                ),
                recordingCapabilities: CockpitRecordingCapabilities(
                  supportsNativeRecording: false,
                ),
                snapshot: CockpitSnapshot(routeName: '/inbox'),
              ).toJson(),
            ),
          );
        } else {
          request.response.statusCode = HttpStatus.notFound;
          request.response.write('{}');
        }
        await request.response.close();
      });

      final remoteAdapter = _FakeCaptureAdapter(
        execution: CockpitCommandExecution(
          result: CockpitCommandResult(
            success: false,
            commandId: 'capture',
            commandType: CockpitCommandType.captureScreenshot,
            durationMs: 9,
            requestedCaptureProfile: CockpitCaptureProfile.acceptance,
            resolvedCaptureKind: CockpitCaptureKind.flutterView,
            error: CockpitCommandError.captureFailed(
              message: 'remote screenshot fallback failed',
            ),
          ),
        ),
      );
      final hostAdapter = _FakeCaptureAdapter(
        execution: CockpitCommandExecution(
          result: CockpitCommandResult(
            success: false,
            commandId: 'capture',
            commandType: CockpitCommandType.captureScreenshot,
            durationMs: 12,
            requestedCaptureProfile: CockpitCaptureProfile.acceptance,
            error: CockpitCommandError.captureFailed(
              message: 'host screenshot capture failed',
            ),
          ),
        ),
      );

      final adapter = CockpitPrioritizedCaptureAdapter(
        remoteAdapter: remoteAdapter,
        hostAcceptanceAdapter: hostAdapter,
        client: CockpitRemoteSessionClient(
          baseUri: Uri.parse('http://127.0.0.1:${server.port}'),
        ),
      );

      final execution = await adapter.capture(
        CockpitCommand(
          commandId: 'capture',
          commandType: CockpitCommandType.captureScreenshot,
          screenshotRequest: const CockpitScreenshotRequest(
            reason: CockpitScreenshotReason.acceptance,
            name: 'acceptance',
          ),
        ),
      );

      expect(hostAdapter.captureCount, 1);
      expect(remoteAdapter.captureCount, 1);
      expect(execution.result.success, isFalse);
      expect(execution.result.error?.message, 'host screenshot capture failed');
      expect(execution.result.usedCaptureFallback, isTrue);
      expect(execution.result.degradationReason, contains('appFallbackFailed'));
      expect(
        execution.result.degradationReason,
        contains('remote screenshot fallback failed'),
      );
    },
  );

  test(
    'keeps primary host failure metadata when both candidates fail',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((request) async {
        request.response.headers.contentType = ContentType.json;
        if (request.uri.path == '/commands/execute') {
          request.response.write(
            jsonEncode(
              CockpitCommandResult(
                success: true,
                commandId: 'wait-for-idle',
                commandType: CockpitCommandType.waitForUiIdle,
                durationMs: 5,
              ).toJson(),
            ),
          );
        } else if (request.uri.path == '/health') {
          request.response.write(
            jsonEncode(
              CockpitRemoteSessionStatus(
                sessionId: 'app-session',
                platform: 'macos',
                transportType: 'remoteHttp',
                currentRouteName: '/inbox',
                capabilities: CockpitCapabilities(
                  platform: 'macos',
                  transportType: 'remoteHttp',
                  supportsInAppControl: true,
                  supportsFlutterViewCapture: true,
                  supportsNativeScreenCapture: false,
                  supportsHostAutomation: false,
                  supportedCommands: const <CockpitCommandType>[
                    CockpitCommandType.captureScreenshot,
                    CockpitCommandType.waitForUiIdle,
                  ],
                ),
                recordingCapabilities: CockpitRecordingCapabilities(
                  supportsNativeRecording: false,
                ),
                snapshot: CockpitSnapshot(routeName: '/inbox'),
              ).toJson(),
            ),
          );
        } else {
          request.response.statusCode = HttpStatus.notFound;
          request.response.write('{}');
        }
        await request.response.close();
      });

      final remoteAdapter = _FakeCaptureAdapter(
        execution: CockpitCommandExecution(
          result: CockpitCommandResult(
            success: false,
            commandId: 'capture',
            commandType: CockpitCommandType.captureScreenshot,
            durationMs: 9,
            requestedCaptureProfile: CockpitCaptureProfile.acceptance,
            resolvedCaptureKind: CockpitCaptureKind.flutterView,
            error: CockpitCommandError.captureFailed(
              message: 'remote capture failed',
            ),
          ),
        ),
      );
      final hostAdapter = _ThrowingCaptureAdapter(StateError('host exploded'));
      final adapter = CockpitPrioritizedCaptureAdapter(
        remoteAdapter: remoteAdapter,
        hostAcceptanceAdapter: hostAdapter,
        client: CockpitRemoteSessionClient(
          baseUri: Uri.parse('http://127.0.0.1:${server.port}'),
        ),
      );

      final execution = await adapter.capture(
        CockpitCommand(
          commandId: 'capture',
          commandType: CockpitCommandType.captureScreenshot,
          screenshotRequest: const CockpitScreenshotRequest(
            reason: CockpitScreenshotReason.acceptance,
            name: 'acceptance',
          ),
        ),
      );

      expect(remoteAdapter.captureCount, 1);
      expect(execution.result.success, isFalse);
      expect(execution.result.usedCaptureFallback, isTrue);
      expect(execution.result.degradationReason, contains('hostCaptureThrew'));
      expect(execution.result.degradationReason, contains('appFallbackFailed'));
      expect(execution.result.error?.message, 'Host screenshot capture threw.');
    },
  );

  test('preserves both stack traces when both candidates throw', () async {
    final hostAdapter = _ThrowingCaptureAdapter(StateError('host exploded'));
    final remoteAdapter = _ThrowingCaptureAdapter(StateError('app exploded'));
    final adapter = CockpitPrioritizedCaptureAdapter(
      remoteAdapter: remoteAdapter,
      hostAcceptanceAdapter: hostAdapter,
      client: CockpitRemoteSessionClient(
        baseUri: Uri.parse('http://127.0.0.1:1'),
      ),
      preCaptureIdleTimeout: const Duration(milliseconds: 1),
    );

    final execution = await adapter.capture(
      CockpitCommand(
        commandId: 'capture',
        commandType: CockpitCommandType.captureScreenshot,
        screenshotRequest: const CockpitScreenshotRequest(
          reason: CockpitScreenshotReason.acceptance,
          name: 'acceptance',
        ),
      ),
    );

    expect(execution.result.success, isFalse);
    expect(execution.result.error?.details['error'], contains('host exploded'));
    expect(
      execution.result.error?.details['stackTrace'],
      isA<String>().having((value) => value, 'value', isNotEmpty),
    );
    expect(execution.result.error?.details['fallbackFailure'], <
      String,
      Object?
    >{
      'source': 'app',
      'threw': true,
      'error': contains('app exploded'),
      'stackTrace': isA<String>().having((value) => value, 'value', isNotEmpty),
    });
  });
}

final class _FakeCaptureAdapter implements CockpitCaptureAdapter {
  _FakeCaptureAdapter({required this.execution});

  final CockpitCommandExecution execution;
  int captureCount = 0;

  @override
  Future<CockpitCommandExecution> capture(CockpitCommand command) async {
    captureCount += 1;
    return execution;
  }
}

CockpitCommandExecution _successfulCapture({
  required String path,
  required CockpitCaptureKind kind,
}) {
  return CockpitCommandExecution(
    result: CockpitCommandResult(
      success: true,
      commandId: 'capture',
      commandType: CockpitCommandType.captureScreenshot,
      durationMs: 4,
      artifacts: <CockpitArtifactRef>[
        CockpitArtifactRef(role: 'screenshot', relativePath: path),
      ],
      requestedCaptureProfile: CockpitCaptureProfile.acceptance,
      resolvedCaptureKind: kind,
    ),
  );
}

final class _ThrowingCaptureAdapter implements CockpitCaptureAdapter {
  _ThrowingCaptureAdapter(this.error);

  final Object error;
  int captureCount = 0;

  @override
  Future<CockpitCommandExecution> capture(CockpitCommand command) async {
    captureCount += 1;
    throw error;
  }
}
