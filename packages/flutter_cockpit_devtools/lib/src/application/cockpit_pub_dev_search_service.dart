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
    this.homepageUrl,
    this.repositoryUrl,
    this.documentationUrl,
    this.license,
    this.topics = const <String>[],
  });

  final String packageName;
  final String latestVersion;
  final String description;
  final String? publisher;
  final int grantedPoints;
  final int maxPoints;
  final int likeCount;
  final double popularityScore;
  final String? homepageUrl;
  final String? repositoryUrl;
  final String? documentationUrl;
  final String? license;
  final List<String> topics;

  Map<String, Object?> toJson() => <String, Object?>{
        'package_name': packageName,
        'latest_version': latestVersion,
        'description': description,
        'publisher': publisher,
        'granted_points': grantedPoints,
        'max_points': maxPoints,
        'like_count': likeCount,
        'popularity_score': popularityScore,
        'homepage_url': homepageUrl,
        'repository_url': repositoryUrl,
        'documentation_url': documentationUrl,
        'license': license,
        'topics': topics,
      };
}

final class CockpitPubDevSearchResult {
  const CockpitPubDevSearchResult({
    required this.results,
    this.warnings = const <String>[],
    this.suggestion,
  });

  final List<CockpitPubDevPackageSummary> results;
  final List<String> warnings;
  final String? suggestion;

  Map<String, Object?> toJson() => <String, Object?>{
        'results':
            results.map((result) => result.toJson()).toList(growable: false),
        'warnings': warnings,
        'suggestion': suggestion,
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
    final warnings = <String>[];
    for (final entry in packages) {
      final packageName = entry['package'] as String;
      Map<Object?, Object?>? packageJson;
      Map<Object?, Object?> latest = const <Object?, Object?>{};
      Map<Object?, Object?> pubspec = const <Object?, Object?>{};
      try {
        packageJson = jsonDecode(
          await _httpClient
              .read(Uri.https('pub.dev', '/api/packages/$packageName')),
        ) as Map<Object?, Object?>;
        latest = Map<Object?, Object?>.from(
          packageJson['latest'] as Map<Object?, Object?>? ??
              const <Object?, Object?>{},
        );
        pubspec = Map<Object?, Object?>.from(
          latest['pubspec'] as Map<Object?, Object?>? ??
              const <Object?, Object?>{},
        );
      } on Object {
        warnings.add('Package details unavailable for $packageName.');
      }
      Map<Object?, Object?> scoreJson = const <Object?, Object?>{};
      try {
        scoreJson = jsonDecode(
          await _httpClient
              .read(Uri.https('pub.dev', '/api/packages/$packageName/score')),
        ) as Map<Object?, Object?>;
      } on Object {
        warnings.add('Package score unavailable for $packageName.');
      }
      results.add(
        CockpitPubDevPackageSummary(
          packageName: packageName,
          latestVersion: latest['version'] as String? ?? '',
          description: pubspec['description'] as String? ?? '',
          publisher: packageJson?['publisher'] as String?,
          grantedPoints: scoreJson['grantedPoints'] as int? ?? 0,
          maxPoints: scoreJson['maxPoints'] as int? ?? 0,
          likeCount: scoreJson['likeCount'] as int? ?? 0,
          popularityScore:
              (scoreJson['popularityScore'] as num?)?.toDouble() ?? 0,
          homepageUrl: pubspec['homepage'] as String?,
          repositoryUrl: pubspec['repository'] as String?,
          documentationUrl: pubspec['documentation'] as String?,
          license: packageJson?['license'] as String?,
          topics: ((packageJson?['topics'] as List?) ?? const <Object?>[])
              .whereType<String>()
              .toList(growable: false),
        ),
      );
    }
    final suggestion = results.isEmpty || warnings.isNotEmpty
        ? 'Try a shorter query or a more general package term.'
        : null;
    return CockpitPubDevSearchResult(
      results: List.unmodifiable(results),
      warnings: List.unmodifiable(warnings),
      suggestion: suggestion,
    );
  }
}
