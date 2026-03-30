import 'dart:convert';

import '../infrastructure/cockpit_http_client.dart';

final class CockpitPubDevSearchRequest {
  const CockpitPubDevSearchRequest({
    required this.query,
    this.maxResults = 5,
  });

  final String query;
  final int maxResults;
}

final class CockpitPubDevPackageSummary {
  const CockpitPubDevPackageSummary({
    required this.packageName,
    required this.latestVersion,
    required this.description,
    required this.publisher,
    required this.grantedPoints,
    required this.maxPoints,
    required this.likeCount,
    required this.popularityScore,
  });

  final String packageName;
  final String latestVersion;
  final String description;
  final String? publisher;
  final int grantedPoints;
  final int maxPoints;
  final int likeCount;
  final double popularityScore;

  Map<String, Object?> toJson() => <String, Object?>{
        'packageName': packageName,
        'latestVersion': latestVersion,
        'description': description,
        'publisher': publisher,
        'grantedPoints': grantedPoints,
        'maxPoints': maxPoints,
        'likeCount': likeCount,
        'popularityScore': popularityScore,
      };
}

final class CockpitPubDevSearchResult {
  const CockpitPubDevSearchResult({required this.results});

  final List<CockpitPubDevPackageSummary> results;

  Map<String, Object?> toJson() => <String, Object?>{
        'results':
            results.map((result) => result.toJson()).toList(growable: false),
      };
}

final class CockpitPubDevSearchService {
  CockpitPubDevSearchService({
    CockpitHttpClient? httpClient,
  }) : _httpClient = httpClient ?? DefaultCockpitHttpClient();

  final CockpitHttpClient _httpClient;

  Future<CockpitPubDevSearchResult> search(
    CockpitPubDevSearchRequest request,
  ) async {
    final searchUri = Uri.https('pub.dev', '/api/search', <String, String>{
      'q': request.query,
    });
    final searchJson =
        jsonDecode(await _httpClient.read(searchUri)) as Map<Object?, Object?>;
    final packages = ((searchJson['packages'] as List?) ?? const <Object?>[])
        .cast<Map<Object?, Object?>>()
        .take(request.maxResults);
    final results = <CockpitPubDevPackageSummary>[];
    for (final entry in packages) {
      final packageName = entry['package'] as String;
      final packageJson = jsonDecode(
        await _httpClient
            .read(Uri.https('pub.dev', '/api/packages/$packageName')),
      ) as Map<Object?, Object?>;
      final latest = Map<Object?, Object?>.from(
        packageJson['latest'] as Map<Object?, Object?>,
      );
      final pubspec = Map<Object?, Object?>.from(
        latest['pubspec'] as Map<Object?, Object?>,
      );
      final scoreJson = jsonDecode(
        await _httpClient
            .read(Uri.https('pub.dev', '/api/packages/$packageName/score')),
      ) as Map<Object?, Object?>;
      results.add(
        CockpitPubDevPackageSummary(
          packageName: packageName,
          latestVersion: latest['version'] as String? ?? '',
          description: pubspec['description'] as String? ?? '',
          publisher: packageJson['publisher'] as String?,
          grantedPoints: scoreJson['grantedPoints'] as int? ?? 0,
          maxPoints: scoreJson['maxPoints'] as int? ?? 0,
          likeCount: scoreJson['likeCount'] as int? ?? 0,
          popularityScore:
              (scoreJson['popularityScore'] as num?)?.toDouble() ?? 0,
        ),
      );
    }
    return CockpitPubDevSearchResult(results: List.unmodifiable(results));
  }
}
