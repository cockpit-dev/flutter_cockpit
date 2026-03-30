import 'package:flutter_cockpit_devtools/src/application/cockpit_pub_dev_search_service.dart';
import 'package:flutter_cockpit_devtools/src/infrastructure/cockpit_http_client.dart';
import 'package:test/test.dart';

void main() {
  test('returns bounded pub.dev package summaries', () async {
    final service = CockpitPubDevSearchService(
      httpClient: _FakeHttpClient(
        responses: <String, String>{
          'https://pub.dev/api/search?q=state+management':
              '{"packages":[{"package":"riverpod"}]}',
          'https://pub.dev/api/packages/riverpod':
              '{"name":"riverpod","publisher":"example.dev","latest":{"version":"2.0.0","pubspec":{"description":"Reactive caching framework."}}}',
          'https://pub.dev/api/packages/riverpod/score':
              '{"grantedPoints":140,"maxPoints":160,"likeCount":120,"popularityScore":0.98}',
        },
      ),
    );

    final result = await service.search(
      const CockpitPubDevSearchRequest(
        query: 'state management',
        maxResults: 1,
      ),
    );

    expect(result.results, hasLength(1));
    expect(result.results.single.packageName, 'riverpod');
    expect(result.results.single.latestVersion, '2.0.0');
    expect(result.results.single.publisher, 'example.dev');
    expect(result.results.single.grantedPoints, 140);
    expect(result.results.single.popularityScore, closeTo(0.98, 0.0001));
  });
}

final class _FakeHttpClient implements CockpitHttpClient {
  const _FakeHttpClient({required this.responses});

  final Map<String, String> responses;

  @override
  Future<String> read(Uri uri) async => responses[uri.toString()]!;

  @override
  Future<List<int>> readBytes(Uri uri) async => throw UnimplementedError();
}
