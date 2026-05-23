import 'dart:convert';
import 'dart:io';

import 'package:flutter_cockpit/flutter_cockpit_flutter.dart';
import 'package:test/test.dart';

void main() {
  test('explicit parent overrides are retained for advanced setups', () {
    final observer = CockpitHttpNetworkObserver();

    expect(observer.hasAttachedParentOverrides, isFalse);
    observer.attachParentOverrides(HttpOverrides.current);
    expect(observer.hasAttachedParentOverrides, isTrue);
  });

  test(
    'CockpitHttpNetworkObserver captures bounded request and response data',
    () async {
      final observer = CockpitHttpNetworkObserver(maxRetainedEntries: 10);
      observer.attachParentOverrides(HttpOverrides.current);

      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() async {
        await server.close(force: true);
      });
      server.listen((request) async {
        final body = await utf8.decoder.bind(request).join();
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode(<String, Object?>{'received': body, 'status': 'ok'}),
        );
        await request.response.close();
      });

      await HttpOverrides.runZoned(() async {
        final client = HttpClient();
        final request = await client.postUrl(
          Uri.parse('http://127.0.0.1:${server.port}/probe'),
        );
        request.headers.contentType = ContentType.json;
        request.add(utf8.encode('{"probe":"sync"}'));
        final response = await request.close();
        await utf8.decoder.bind(response).join();
        client.close(force: true);
      }, createHttpClient: observer.createHttpClient);

      final snapshot = observer.snapshot(maxEntries: 5);
      expect(snapshot.totalEntryCount, 1);
      expect(snapshot.failureCount, 0);
      expect(snapshot.entries, hasLength(1));
      expect(snapshot.endpointSummaries, hasLength(1));
      expect(snapshot.entries.single.method, 'POST');
      expect(snapshot.entries.single.statusCode, 200);
      expect(snapshot.entries.single.uri, contains('/probe'));
      expect(snapshot.entries.single.requestBodyPreview, contains('sync'));
      expect(snapshot.entries.single.responseBodyPreview, contains('status'));
      expect(snapshot.endpointSummaries.single.method, 'POST');
      expect(snapshot.endpointSummaries.single.uriPattern, '/probe');
      expect(snapshot.endpointSummaries.single.requestCount, 1);
    },
  );

  test(
    'CockpitHttpNetworkObserver filters captured traffic for diagnostics',
    () async {
      final observer = CockpitHttpNetworkObserver(maxRetainedEntries: 10);
      observer.attachParentOverrides(HttpOverrides.current);
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() async {
        await server.close(force: true);
      });
      server.listen((request) async {
        switch ((request.method, request.uri.path)) {
          case ('GET', '/tasks'):
            request.response.statusCode = HttpStatus.ok;
            request.response.headers.contentType = ContentType.json;
            request.response.write(jsonEncode(<String, Object?>{'items': 3}));
          case ('POST', '/sync/health'):
            request.response.statusCode = HttpStatus.serviceUnavailable;
            request.response.headers.contentType = ContentType.json;
            request.response.write(
              jsonEncode(<String, Object?>{'error': 'upstream timeout'}),
            );
          case ('POST', '/tasks'):
            request.response.statusCode = HttpStatus.created;
            request.response.headers.contentType = ContentType.json;
            request.response.write(
              jsonEncode(<String, Object?>{'status': 'ok'}),
            );
          default:
            request.response.statusCode = HttpStatus.notFound;
        }
        await request.response.close();
      });

      await HttpOverrides.runZoned(() async {
        final client = HttpClient();
        final tasksResponse = await (await client.getUrl(
          Uri.parse('http://127.0.0.1:${server.port}/tasks'),
        )).close();
        await utf8.decoder.bind(tasksResponse).join();

        final syncRequest = await client.postUrl(
          Uri.parse('http://127.0.0.1:${server.port}/sync/health'),
        );
        final syncResponse = await syncRequest.close();
        await utf8.decoder.bind(syncResponse).join();

        final createRequest = await client.postUrl(
          Uri.parse('http://127.0.0.1:${server.port}/tasks'),
        );
        final createResponse = await createRequest.close();
        await utf8.decoder.bind(createResponse).join();
        client.close(force: true);
      }, createHttpClient: observer.createHttpClient);

      final snapshot = observer.snapshot(
        maxEntries: 4,
        query: const CockpitNetworkQuery(
          method: 'POST',
          uriContains: '/sync',
          onlyFailures: true,
          statusCodeAtLeast: 500,
        ),
      );

      expect(snapshot.capturedEntryCount, 3);
      expect(snapshot.totalEntryCount, 1);
      expect(snapshot.failureCount, 1);
      expect(snapshot.query.onlyFailures, isTrue);
      expect(snapshot.entries.single.uri, contains('/sync/health'));
      expect(snapshot.endpointSummaries, hasLength(1));
      expect(snapshot.endpointSummaries.single.uriPattern, '/sync/health');
      expect(snapshot.endpointSummaries.single.failureCount, 1);
    },
  );

  test(
    'CockpitHttpNetworkObserver can wait until captured traffic goes idle',
    () async {
      final observer = CockpitHttpNetworkObserver(maxRetainedEntries: 10);
      observer.attachParentOverrides(HttpOverrides.current);
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() async {
        await server.close(force: true);
      });
      server.listen((request) async {
        await Future<void>.delayed(const Duration(milliseconds: 90));
        request.response.statusCode = HttpStatus.ok;
        await request.response.close();
      });

      final requestFuture = HttpOverrides.runZoned(() async {
        final client = HttpClient();
        final request = await client.getUrl(
          Uri.parse('http://127.0.0.1:${server.port}/slow'),
        );
        final response = await request.close();
        await response.drain<void>();
        client.close(force: true);
      }, createHttpClient: observer.createHttpClient);

      final waitFuture = observer.waitForIdle(
        quietWindow: const Duration(milliseconds: 40),
        timeout: const Duration(seconds: 2),
      );

      await requestFuture;

      expect(await waitFuture, isTrue);
      expect(observer.snapshot(maxEntries: 2).inFlightCount, 0);
    },
  );

  test(
    'CockpitHttpNetworkObserver uses the injected tick handler while polling for idle',
    () async {
      var tickCount = 0;
      final observer = CockpitHttpNetworkObserver(
        tickHandler: (duration) async {
          tickCount += 1;
          await Future<void>.microtask(() {});
        },
      );
      observer.markRequestStarted();
      Future<void>.microtask(() {
        observer.clear();
      });

      final didGoIdle = await observer.waitForIdle(
        quietWindow: Duration.zero,
        timeout: const Duration(milliseconds: 80),
      );

      expect(didGoIdle, isTrue);
      expect(tickCount, greaterThan(0));
    },
  );

  test(
    'CockpitHttpNetworkObserver records connection failures raised before a request is returned',
    () async {
      final observer = CockpitHttpNetworkObserver(maxRetainedEntries: 10);
      observer.attachParentOverrides(_ThrowingHttpOverrides());

      final client = observer.createHttpClient(null);

      await expectLater(
        client.getUrl(Uri.parse('http://127.0.0.1:63341/sync/health')),
        throwsA(isA<SocketException>()),
      );

      final snapshot = observer.snapshot(maxEntries: 5);
      expect(snapshot.totalEntryCount, 1);
      expect(snapshot.failureCount, 1);
      expect(snapshot.entries.single.method, 'GET');
      expect(snapshot.entries.single.uri, contains('/sync/health'));
      expect(snapshot.entries.single.error, contains('Connection failed'));
      expect(snapshot.inFlightCount, 0);
    },
  );
}

final class _ThrowingHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return _ThrowingHttpClient();
  }
}

final class _ThrowingHttpClient implements HttpClient {
  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) {
    throw SocketException(
      'Connection failed',
      address: InternetAddress('127.0.0.1'),
      port: 63341,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
