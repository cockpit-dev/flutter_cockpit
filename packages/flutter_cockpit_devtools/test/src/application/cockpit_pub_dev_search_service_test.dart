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
              '{"name":"riverpod","publisher":"example.dev","latest":{"version":"2.0.0","pubspec":{"description":"Reactive caching framework.","homepage":"https://riverpod.dev","repository":"https://github.com/rrousselGit/riverpod"}},"topics":["state-management","reactive"],"license":"MIT"}',
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
    expect(result.results.single.homepageUrl, 'https://riverpod.dev');
    expect(
      result.results.single.repositoryUrl,
      'https://github.com/rrousselGit/riverpod',
    );
    expect(
        result.results.single.topics, <String>['state-management', 'reactive']);
    expect(result.results.single.license, 'MIT');
    expect(result.warnings, isEmpty);
    expect(result.suggestion, isNull);
  });

  test('returns suggestions and warnings for empty and partial results',
      () async {
    final service = CockpitPubDevSearchService(
      httpClient: _FakeHttpClient(
        responses: <String, String>{
          'https://pub.dev/api/search?q=obscure+thing':
              '{"packages":[{"package":"mystery_pkg"}]}',
          'https://pub.dev/api/packages/mystery_pkg':
              '{"name":"mystery_pkg","latest":{"version":"0.1.0","pubspec":{"description":"Unknown helper."}}}',
        },
        failingUris: <String>{
          'https://pub.dev/api/packages/mystery_pkg/score',
        },
      ),
    );

    final result = await service.search(
      const CockpitPubDevSearchRequest(query: 'obscure thing'),
    );

    expect(result.results.single.packageName, 'mystery_pkg');
    expect(result.results.single.latestVersion, '0.1.0');
    expect(result.warnings, isNotEmpty);
    expect(result.suggestion, contains('Try'));
  });
}

final class _FakeHttpClient implements CockpitHttpClient {
  const _FakeHttpClient({
    required this.responses,
    this.failingUris = const <String>{},
  });

  final Map<String, String> responses;
  final Set<String> failingUris;

  @override
  Future<String> read(Uri uri) async {
    if (failingUris.contains(uri.toString())) {
      throw StateError('network failed');
    }
    return responses[uri.toString()]!;
  }

  @override
  Future<List<int>> readBytes(Uri uri) async => throw UnimplementedError();
}
