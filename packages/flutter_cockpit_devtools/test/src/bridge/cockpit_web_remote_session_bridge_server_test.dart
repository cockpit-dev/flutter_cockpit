import 'dart:convert';
import 'dart:io';

import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:flutter_cockpit/flutter_cockpit_remote_bridge.dart';
import 'package:flutter_cockpit_devtools/src/bridge/cockpit_web_remote_session_bridge_server.dart';
import 'package:flutter_cockpit_devtools/src/recording/cockpit_host_recording_adapter.dart';
import 'package:test/test.dart';

void main() {
  test(
    'web bridge proxies browser endpoints and serves host recording artifacts',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'cockpit_web_remote_session_bridge_artifacts',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });
      final sourceFile = File('${tempDir.path}/recordings/web-acceptance.mp4')
        ..parent.createSync(recursive: true);
      final startedRecordings = <CockpitRecordingRequest>[];
      var stopRecordingCount = 0;
      final server = CockpitWebRemoteSessionBridgeServer(
        bindHost: '127.0.0.1',
        bindPort: 0,
        routePrefix: '/cockpit',
        recordingAdapter: _FakeHostRecordingAdapter(
          onStart: (request) async {
            startedRecordings.add(request);
            return CockpitRecordingSession(
              request: request,
              state: CockpitRecordingState.recording,
            );
          },
          onStop: () async {
            stopRecordingCount += 1;
            sourceFile.writeAsStringSync('host-recording');
            return CockpitRecordingResult(
              state: CockpitRecordingState.completed,
              purpose: CockpitRecordingPurpose.acceptance,
              recordingKind: CockpitRecordingKind.nativeScreen,
              artifact: const CockpitArtifactRef(
                role: 'recording',
                relativePath: 'recordings/web-acceptance.mp4',
              ),
              sourceFilePath: sourceFile.path,
              durationMs: 1800,
            );
          },
        ),
      );
      await server.start();
      addTearDown(server.close);
      expect(server.baseUri.path, '/cockpit');

      final unscopedHealthResponse = await _readBytesResponse(
        server.baseUri.replace(path: '/health'),
      );
      expect(unscopedHealthResponse.statusCode, HttpStatus.notFound);

      final socket = await WebSocket.connect(server.connectUri.toString());
      addTearDown(socket.close);

      socket.listen((payload) {
        final message = CockpitRemoteBridgeRequest.fromJson(
          Map<String, Object?>.from(
            jsonDecode(payload as String) as Map<Object?, Object?>,
          ),
        );
        final messagePath = Uri.parse(message.path).path;
        switch (messagePath) {
          case '/cockpit/health':
            socket.add(
              jsonEncode(
                CockpitRemoteBridgeResponse(
                  requestId: message.requestId,
                  statusCode: 200,
                  jsonBody: <String, Object?>{
                    'sessionId': 'web-session',
                    'platform': 'web',
                    'transportType': 'remoteHttp',
                    'currentRouteName': '/inbox',
                    'capabilities': CockpitCapabilities(
                      platform: 'web',
                      transportType: 'remoteHttp',
                      supportsInAppControl: true,
                      supportsFlutterViewCapture: true,
                      supportsNativeScreenCapture: false,
                      supportsHostAutomation: false,
                    ).toJson(),
                    'recordingCapabilities': CockpitRecordingCapabilities(
                      supportsNativeRecording: false,
                    ).toJson(),
                    'snapshot': CockpitSnapshot(routeName: '/inbox').toJson(),
                  },
                ).toJson(),
              ),
            );
          case '/cockpit/commands/execute':
            socket.add(
              jsonEncode(
                CockpitRemoteBridgeResponse(
                  requestId: message.requestId,
                  statusCode: 200,
                  jsonBody: <String, Object?>{
                    'result': CockpitCommandResult(
                      success: true,
                      commandId: 'tap-open',
                      commandType: CockpitCommandType.tap,
                      durationMs: 12,
                      artifacts: const <CockpitArtifactRef>[
                        CockpitArtifactRef(
                          role: 'screenshot',
                          relativePath: 'browser/screenshot.png',
                        ),
                      ],
                    ).toJson(),
                    'artifactPayloads': <Object?>[
                      const CockpitRemoteArtifactPayload(
                        artifact: CockpitArtifactRef(
                          role: 'screenshot',
                          relativePath: 'browser/screenshot.png',
                        ),
                        bytes: <int>[1, 2, 3, 4],
                      ).toJson(),
                    ],
                  },
                ).toJson(),
              ),
            );
          case '/cockpit/artifacts/download':
            socket.add(
              jsonEncode(
                CockpitRemoteBridgeResponse(
                  requestId: message.requestId,
                  statusCode: 200,
                  bytesBase64: base64Encode(utf8.encode('browser-artifact')),
                ).toJson(),
              ),
            );
          default:
            socket.add(
              jsonEncode(
                CockpitRemoteBridgeResponse(
                  requestId: message.requestId,
                  statusCode: 404,
                  jsonBody: <String, Object?>{'error': 'not_found'},
                ).toJson(),
              ),
            );
        }
      });

      final healthJson = await _readJson(Uri.parse('${server.baseUri}/health'));
      expect(
        (healthJson['recordingCapabilities']
            as Map<String, Object?>)['supportsNativeRecording'],
        isTrue,
      );
      expect(
        ((healthJson['recordingCapabilities']
                    as Map<String, Object?>)['recordingLimitations']!
                as List<Object?>)
            .single,
        contains('requires screen-capture permission'),
      );
      expect(
        ((healthJson['recordingCapabilities']
                    as Map<String, Object?>)['recordingLimitations']!
                as List<Object?>)
            .single,
        contains('best-effort'),
      );

      final startJson = await _postJson(
        Uri.parse('${server.baseUri}/recording/start'),
        const CockpitRecordingRequest(
          purpose: CockpitRecordingPurpose.acceptance,
          name: 'web_acceptance',
        ).toJson(),
      );
      expect(startedRecordings, hasLength(1));
      expect(startJson['state'], 'recording');

      final commandJson = await _postJson(
        Uri.parse('${server.baseUri}/commands/execute'),
        CockpitCommand(
          commandId: 'tap-open',
          commandType: CockpitCommandType.tap,
        ).toJson(),
      );
      expect(
        ((commandJson['result'] as Map<String, Object?>)['success']) as bool,
        isTrue,
      );
      expect(commandJson['artifactPayloads'], isEmpty);
      final commandDownloads =
          (commandJson['artifactDownloads'] as List<Object?>)
              .cast<Map<Object?, Object?>>();
      expect(commandDownloads, hasLength(1));
      final commandDownloadPath =
          commandDownloads.single['downloadPath']! as String;
      expect(
        commandDownloadPath,
        startsWith('/cockpit/artifacts/download?path='),
      );
      final commandArtifactBytes = await _readBytes(
        server.baseUri.resolve(commandDownloadPath),
      );
      expect(commandArtifactBytes, <int>[1, 2, 3, 4]);

      final stopJson = await _postJson(
        Uri.parse('${server.baseUri}/recording/stop'),
        const <String, Object?>{},
      );
      expect(stopRecordingCount, 1);
      final downloads = (stopJson['artifactDownloads'] as List<Object?>)
          .cast<Map<Object?, Object?>>();
      expect(downloads, hasLength(1));
      final downloadPath = downloads.single['downloadPath']! as String;
      expect(downloadPath, startsWith('/cockpit/artifacts/download?path='));

      final hostRecordingBytes = await _readBytes(
        server.baseUri.resolve(downloadPath),
      );
      expect(utf8.decode(hostRecordingBytes), 'host-recording');
      sourceFile.deleteSync();
      final deletedResponse = await _readBytesResponse(
        server.baseUri.resolve(downloadPath),
      );
      expect(deletedResponse.statusCode, HttpStatus.notFound);

      final missingBrowserProxyArtifact = await _readBytesResponse(
        Uri.parse(
          '${server.baseUri}/artifacts/download?path=browser%2Fproxied.png',
        ),
      );
      expect(missingBrowserProxyArtifact.statusCode, HttpStatus.ok);
      expect(
        utf8.decode(missingBrowserProxyArtifact.bytes),
        'browser-artifact',
      );
    },
  );

  test(
    'web bridge returns a structured prerequisite failure when host recording cannot start',
    () async {
      final server = CockpitWebRemoteSessionBridgeServer(
        bindHost: '127.0.0.1',
        bindPort: 0,
        recordingAdapter: _FakeHostRecordingAdapter(
          onStart: (_) async {
            throw StateError('Screen Recording permission is missing.');
          },
          onStop: () async => throw StateError('no active recording'),
        ),
      );
      await server.start();
      addTearDown(server.close);

      final response = await _postJsonResponse(
        server.baseUri.resolve('/recording/start'),
        const CockpitRecordingRequest(
          purpose: CockpitRecordingPurpose.acceptance,
          name: 'web_acceptance',
        ).toJson(),
      );

      expect(response.statusCode, HttpStatus.preconditionFailed);
      expect(response.body['error'], 'recordingStartFailed');
      expect(
        response.body['message'],
        contains('Screen Recording permission is missing.'),
      );
    },
  );

  test(
    'web bridge externalizes inline recording bytes without bloating JSON responses',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'cockpit_web_bridge_inline_recording',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });
      final generatedFile = File('${tempDir.path}/web-inline.mp4');
      final server = CockpitWebRemoteSessionBridgeServer(
        bindHost: '127.0.0.1',
        bindPort: 0,
        artifactTempFileFactory: (_) async => generatedFile,
        recordingAdapter: _FakeHostRecordingAdapter(
          onStart: (request) async => CockpitRecordingSession(
            request: request,
            state: CockpitRecordingState.recording,
          ),
          onStop: () async => CockpitRecordingResult(
            state: CockpitRecordingState.completed,
            purpose: CockpitRecordingPurpose.acceptance,
            recordingKind: CockpitRecordingKind.nativeScreen,
            artifact: const CockpitArtifactRef(
              role: 'recording',
              relativePath: 'recordings/web-inline.mp4',
            ),
            bytes: const <int>[4, 3, 2, 1],
            sourceFilePath: '/browser/private/web-inline.mp4',
            durationMs: 1200,
          ),
        ),
      );
      await server.start();

      await _postJson(
        server.baseUri.resolve('/recording/start'),
        const CockpitRecordingRequest(
          purpose: CockpitRecordingPurpose.acceptance,
          name: 'web_inline',
        ).toJson(),
      );

      final stopJson = await _postJson(
        server.baseUri.resolve('/recording/stop'),
        const <String, Object?>{},
      );
      final resultPayload = Map<String, Object?>.from(
        stopJson['result']! as Map<Object?, Object?>,
      );
      expect(resultPayload.containsKey('bytes'), isFalse);
      expect(resultPayload.containsKey('sourceFilePath'), isFalse);
      final downloads = (stopJson['artifactDownloads'] as List<Object?>)
          .cast<Map<Object?, Object?>>();
      expect(downloads, hasLength(1));

      expect(
        await _readBytes(
          server.baseUri.resolve(downloads.single['downloadPath']! as String),
        ),
        <int>[4, 3, 2, 1],
      );
      expect(generatedFile.existsSync(), isTrue);

      await server.close();
      expect(generatedFile.existsSync(), isFalse);
    },
  );

  test(
    'web bridge stops an active host recording when the server closes',
    () async {
      var stopRecordingCount = 0;
      final server = CockpitWebRemoteSessionBridgeServer(
        bindHost: '127.0.0.1',
        bindPort: 0,
        recordingAdapter: _FakeHostRecordingAdapter(
          onStart: (request) async => CockpitRecordingSession(
            request: request,
            state: CockpitRecordingState.recording,
          ),
          onStop: () async {
            stopRecordingCount += 1;
            return CockpitRecordingResult(
              state: CockpitRecordingState.completed,
              purpose: CockpitRecordingPurpose.acceptance,
              recordingKind: CockpitRecordingKind.nativeScreen,
            );
          },
        ),
      );
      await server.start();

      await _postJson(
        server.baseUri.resolve('/recording/start'),
        const CockpitRecordingRequest(
          purpose: CockpitRecordingPurpose.acceptance,
          name: 'web_acceptance',
        ).toJson(),
      );

      await server.close();

      expect(stopRecordingCount, 1);
    },
  );

  test('web bridge default timeout leaves remote client headroom', () {
    final server = CockpitWebRemoteSessionBridgeServer(
      bindHost: '127.0.0.1',
      bindPort: 0,
    );

    expect(server.requestTimeout, const Duration(seconds: 20));
    expect(server.requestTimeout, lessThan(const Duration(seconds: 30)));
  });

  test(
    'web bridge returns a structured timeout when the browser is unresponsive',
    () async {
      final server = CockpitWebRemoteSessionBridgeServer(
        bindHost: '127.0.0.1',
        bindPort: 0,
        requestTimeout: const Duration(milliseconds: 50),
      );
      await server.start();
      addTearDown(server.close);

      final socket = await WebSocket.connect(server.connectUri.toString());
      addTearDown(socket.close);
      socket.listen((_) {});

      final stopwatch = Stopwatch()..start();
      final response = await _readJsonResponse(
        server.baseUri.resolve('/health'),
      );
      stopwatch.stop();

      expect(response.statusCode, HttpStatus.gatewayTimeout);
      expect(response.body['error'], 'bridgeTimeout');
      expect(
        response.body['message'],
        contains('browser bridge did not respond'),
      );
      expect(stopwatch.elapsed, lessThan(const Duration(seconds: 2)));
    },
  );

  test(
    'web bridge honors command timeoutMs before timing out command execution',
    () async {
      final server = CockpitWebRemoteSessionBridgeServer(
        bindHost: '127.0.0.1',
        bindPort: 0,
        requestTimeout: const Duration(milliseconds: 50),
      );
      await server.start();
      addTearDown(server.close);

      final socket = await WebSocket.connect(server.connectUri.toString());
      addTearDown(socket.close);
      socket.listen((payload) async {
        final message = CockpitRemoteBridgeRequest.fromJson(
          Map<String, Object?>.from(
            jsonDecode(payload as String) as Map<Object?, Object?>,
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 120));
        socket.add(
          jsonEncode(
            CockpitRemoteBridgeResponse(
              requestId: message.requestId,
              statusCode: 200,
              jsonBody: <String, Object?>{
                'result': CockpitCommandResult(
                  success: true,
                  commandId: 'slow-wait',
                  commandType: CockpitCommandType.waitFor,
                  durationMs: 120,
                ).toJson(),
              },
            ).toJson(),
          ),
        );
      });

      final response = await _postJsonResponse(
        server.baseUri.resolve('/commands/execute'),
        CockpitCommand(
          commandId: 'slow-wait',
          commandType: CockpitCommandType.waitFor,
          timeoutMs: 500,
        ).toJson(),
      );

      expect(response.statusCode, HttpStatus.ok);
      expect(
        ((response.body['result'] as Map<String, Object?>)['success']) as bool,
        isTrue,
      );
    },
  );

  test(
    'web bridge reports malformed browser responses without timeout',
    () async {
      final server = CockpitWebRemoteSessionBridgeServer(
        bindHost: '127.0.0.1',
        bindPort: 0,
        requestTimeout: const Duration(seconds: 5),
      );
      await server.start();
      addTearDown(server.close);

      final socket = await WebSocket.connect(server.connectUri.toString());
      addTearDown(socket.close);
      socket.listen((_) {
        socket.add(
          jsonEncode(const <String, Object?>{
            'statusCode': 200,
            'jsonBody': <String, Object?>{'ok': true},
          }),
        );
      });

      final stopwatch = Stopwatch()..start();
      final response = await _readJsonResponse(
        server.baseUri.resolve('/health'),
      );
      stopwatch.stop();

      expect(response.statusCode, HttpStatus.badGateway);
      expect(response.body['error'], 'bridgeInvalidResponse');
      expect(
        response.body['message'],
        contains('"requestId" must be a non-empty string'),
      );
      expect(stopwatch.elapsed, lessThan(const Duration(seconds: 2)));
    },
  );

  test(
    'web bridge reports unknown browser response ids without timeout',
    () async {
      final server = CockpitWebRemoteSessionBridgeServer(
        bindHost: '127.0.0.1',
        bindPort: 0,
        requestTimeout: const Duration(seconds: 5),
      );
      await server.start();
      addTearDown(server.close);

      final socket = await WebSocket.connect(server.connectUri.toString());
      addTearDown(socket.close);
      socket.listen((_) {
        socket.add(
          jsonEncode(
            const CockpitRemoteBridgeResponse(
              requestId: 'wrong-request-id',
              statusCode: 200,
              jsonBody: <String, Object?>{'ok': true},
            ).toJson(),
          ),
        );
      });

      final stopwatch = Stopwatch()..start();
      final response = await _readJsonResponse(
        server.baseUri.resolve('/health'),
      );
      stopwatch.stop();

      expect(response.statusCode, HttpStatus.badGateway);
      expect(response.body['error'], 'bridgeUnknownResponse');
      expect(response.body['message'], contains('wrong-request-id'));
      expect(stopwatch.elapsed, lessThan(const Duration(seconds: 2)));
    },
  );

  test(
    'web bridge reports invalid binary bridge responses without timeout',
    () async {
      final server = CockpitWebRemoteSessionBridgeServer(
        bindHost: '127.0.0.1',
        bindPort: 0,
        requestTimeout: const Duration(seconds: 5),
      );
      await server.start();
      addTearDown(server.close);

      final socket = await WebSocket.connect(server.connectUri.toString());
      addTearDown(socket.close);
      socket.listen((payload) {
        final message = CockpitRemoteBridgeRequest.fromJson(
          Map<String, Object?>.from(
            jsonDecode(payload as String) as Map<Object?, Object?>,
          ),
        );
        socket.add(
          jsonEncode(
            CockpitRemoteBridgeResponse(
              requestId: message.requestId,
              statusCode: 200,
              bytesBase64: 'not base64',
            ).toJson(),
          ),
        );
      });

      final stopwatch = Stopwatch()..start();
      final response = await _readJsonResponse(
        Uri.parse('${server.baseUri}/artifacts/download?path=image.png'),
      );
      stopwatch.stop();

      expect(response.statusCode, HttpStatus.badGateway);
      expect(response.body['error'], 'bridgeInvalidResponse');
      expect(response.body['message'], contains('"bytesBase64"'));
      expect(stopwatch.elapsed, lessThan(const Duration(seconds: 2)));
    },
  );
}

final class _FakeHostRecordingAdapter implements CockpitHostRecordingAdapter {
  const _FakeHostRecordingAdapter({
    required this.onStart,
    required this.onStop,
  });

  final Future<CockpitRecordingSession> Function(
    CockpitRecordingRequest request,
  )
  onStart;
  final Future<CockpitRecordingResult> Function() onStop;

  @override
  Future<CockpitRecordingSession> startRecording(
    CockpitRecordingRequest request,
  ) {
    return onStart(request);
  }

  @override
  Future<CockpitRecordingResult> stopRecording() {
    return onStop();
  }
}

Future<Map<String, Object?>> _readJson(Uri uri) async {
  return (await _readJsonResponse(uri)).body;
}

Future<_HttpJsonResponse> _readJsonResponse(Uri uri) async {
  final client = HttpClient();
  try {
    final request = await client.getUrl(uri);
    final response = await request.close();
    final payload = await utf8.decoder.bind(response).join();
    return _HttpJsonResponse(
      statusCode: response.statusCode,
      body: Map<String, Object?>.from(
        jsonDecode(payload) as Map<Object?, Object?>,
      ),
    );
  } finally {
    client.close(force: true);
  }
}

Future<Map<String, Object?>> _postJson(
  Uri uri,
  Map<String, Object?> body,
) async {
  final response = await _postJsonResponse(uri, body);
  return response.body;
}

Future<_HttpJsonResponse> _postJsonResponse(
  Uri uri,
  Map<String, Object?> body,
) async {
  final client = HttpClient();
  try {
    final request = await client.postUrl(uri);
    request.headers.contentType = ContentType.json;
    request.write(jsonEncode(body));
    final response = await request.close();
    final payload = await utf8.decoder.bind(response).join();
    return _HttpJsonResponse(
      statusCode: response.statusCode,
      body: Map<String, Object?>.from(
        jsonDecode(payload) as Map<Object?, Object?>,
      ),
    );
  } finally {
    client.close(force: true);
  }
}

Future<List<int>> _readBytes(Uri uri) async {
  final response = await _readBytesResponse(uri);
  return response.bytes;
}

Future<_HttpBytesResponse> _readBytesResponse(Uri uri) async {
  final client = HttpClient();
  try {
    final request = await client.getUrl(uri);
    final response = await request.close();
    final bytes = await response.fold<List<int>>(<int>[], (bytes, chunk) {
      final next = List<int>.of(bytes);
      next.addAll(chunk);
      return next;
    });
    return _HttpBytesResponse(statusCode: response.statusCode, bytes: bytes);
  } finally {
    client.close(force: true);
  }
}

final class _HttpJsonResponse {
  const _HttpJsonResponse({required this.statusCode, required this.body});

  final int statusCode;
  final Map<String, Object?> body;
}

final class _HttpBytesResponse {
  const _HttpBytesResponse({required this.statusCode, required this.bytes});

  final int statusCode;
  final List<int> bytes;
}
