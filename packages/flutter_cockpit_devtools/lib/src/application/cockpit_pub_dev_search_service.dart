import 'dart:convert';

import 'cockpit_application_service_exception.dart';
import '../infrastructure/cockpit_http_client.dart';
import '../infrastructure/cockpit_process_manager.dart';

final class CockpitPubDevSearchRequest {
  const CockpitPubDevSearchRequest({
    required this.query,
    this.maxResults = 5,
    this.timeout = const Duration(seconds: 20),
  });

  final String query;
  final int maxResults;
  final Duration timeout;
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
    'packageName': packageName,
    'latestVersion': latestVersion,
    'description': description,
    'publisher': publisher,
    'grantedPoints': grantedPoints,
    'maxPoints': maxPoints,
    'likeCount': likeCount,
    'popularityScore': popularityScore,
    'homepageUrl': homepageUrl,
    'repositoryUrl': repositoryUrl,
    'documentationUrl': documentationUrl,
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
    'results': results.map((result) => result.toJson()).toList(growable: false),
    'warnings': warnings,
    'suggestion': suggestion,
  };
}

final class CockpitPubDevSearchService {
  CockpitPubDevSearchService({
    CockpitHttpClient? httpClient,
    CockpitProcessManager? processManager,
    bool? enableProcessFallback,
  }) : _httpClient = httpClient ?? DefaultCockpitHttpClient(),
       _processManager = processManager ?? const LocalCockpitProcessManager(),
       _enableProcessFallback = enableProcessFallback ?? httpClient == null;

  final CockpitHttpClient _httpClient;
  final CockpitProcessManager _processManager;
  final bool _enableProcessFallback;

  Future<CockpitPubDevSearchResult> search(
    CockpitPubDevSearchRequest request,
  ) async {
    final searchUri = Uri.https('pub.dev', '/api/search', <String, String>{
      'q': request.query,
    });
    final searchJson =
        jsonDecode(await _read(searchUri, timeout: request.timeout))
            as Map<Object?, Object?>;
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
        packageJson =
            jsonDecode(
                  await _read(
                    Uri.https('pub.dev', '/api/packages/$packageName'),
                    timeout: request.timeout,
                  ),
                )
                as Map<Object?, Object?>;
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
        scoreJson =
            jsonDecode(
                  await _read(
                    Uri.https('pub.dev', '/api/packages/$packageName/score'),
                    timeout: request.timeout,
                  ),
                )
                as Map<Object?, Object?>;
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

  Future<String> _read(Uri uri, {required Duration timeout}) {
    return _readWithFallback(uri, timeout: timeout);
  }

  Future<String> _readWithFallback(Uri uri, {required Duration timeout}) async {
    try {
      return await _httpClient
          .read(uri)
          .timeout(
            timeout,
            onTimeout: () => throw CockpitApplicationServiceException(
              code: 'pubDevSearchTimedOut',
              message: 'pub.dev request timed out.',
              details: <String, Object?>{
                'uri': uri.toString(),
                'timeoutMs': timeout.inMilliseconds,
              },
            ),
          );
    } on Object catch (primaryError) {
      if (!_enableProcessFallback) {
        rethrow;
      }
      try {
        return await _readViaPython(uri, timeout: timeout);
      } on Object catch (fallbackError) {
        throw CockpitApplicationServiceException(
          code: 'pubDevSearchFailed',
          message: 'pub.dev request failed.',
          details: <String, Object?>{
            'uri': uri.toString(),
            'timeoutMs': timeout.inMilliseconds,
            'primaryError': primaryError.toString(),
            'fallbackError': fallbackError.toString(),
          },
        );
      }
    }
  }

  Future<String> _readViaPython(Uri uri, {required Duration timeout}) async {
    final timeoutSeconds = (timeout.inMilliseconds / 1000).ceil().clamp(1, 600);
    final commands = <(String executable, List<String> arguments)>[
      (
        'python3',
        <String>['-c', _pythonFetchScript, uri.toString(), '$timeoutSeconds'],
      ),
      (
        'python',
        <String>['-c', _pythonFetchScript, uri.toString(), '$timeoutSeconds'],
      ),
    ];
    Object? lastError;
    for (final command in commands) {
      try {
        final result = await cockpitRunManagedProcessWithTimeout(
          _processManager,
          command.$1,
          command.$2,
          timeout: timeout + const Duration(seconds: 1),
        );
        final stdout = '${result.stdout}'.trim();
        final stderr = '${result.stderr}'.trim();
        if (result.exitCode == 0 && stdout.isNotEmpty) {
          return stdout;
        }
        lastError = StateError(
          '${command.$1} exited with ${result.exitCode}: $stderr',
        );
      } on Object catch (error) {
        lastError = error;
      }
    }
    throw lastError ??
        StateError('No external fetcher was available for pub.dev.');
  }
}

const String _pythonFetchScript = '''
import sys
import urllib.request

url = sys.argv[1]
timeout = float(sys.argv[2])
with urllib.request.urlopen(url, timeout=timeout) as response:
    sys.stdout.write(response.read().decode('utf-8'))
''';
