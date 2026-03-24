import 'dart:convert';
import 'dart:io';

import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:flutter_cockpit_devtools/src/adapters/cockpit_capture_adapter.dart';
import 'package:flutter_cockpit_devtools/src/capture/cockpit_host_preferred_capture_adapter.dart';
import 'package:flutter_cockpit_devtools/src/remote/cockpit_remote_session_client.dart';
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
          final payload = jsonDecode(await utf8.decoder.bind(request).join())
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
      final adapter = CockpitHostPreferredCaptureAdapter(
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

  test('delegates non-acceptance screenshots to the remote adapter', () async {
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
        ),
      ),
    );
    final adapter = CockpitHostPreferredCaptureAdapter(
      remoteAdapter: remoteAdapter,
      hostAcceptanceAdapter: hostAdapter,
      client: CockpitRemoteSessionClient(
        baseUri: Uri.parse('http://127.0.0.1/'),
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

  test('falls back to remote capture when host acceptance capture fails',
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

    final adapter = CockpitHostPreferredCaptureAdapter(
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
