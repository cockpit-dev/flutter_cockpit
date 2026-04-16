import 'dart:io';

import 'package:path/path.dart' as p;

import 'cockpit_session_path.dart';

String cockpitSelectBestAppBundlePath({
  required Directory searchRoot,
  required String? flavor,
  required p.Context pathContext,
  required String platformLabel,
}) {
  final appBundles = _findTopLevelAppBundles(
    searchRoot: searchRoot,
    pathContext: pathContext,
  );
  if (appBundles.isEmpty) {
    throw StateError(
      'Unable to locate an $platformLabel .app bundle in ${searchRoot.path}.',
    );
  }

  appBundles.sort((left, right) {
    final leftScore = cockpitScoreFlavorMatchingBundlePath(left.path, flavor);
    final rightScore = cockpitScoreFlavorMatchingBundlePath(right.path, flavor);
    if (leftScore != rightScore) {
      return rightScore.compareTo(leftScore);
    }
    return right.statSync().modified.compareTo(left.statSync().modified);
  });
  return appBundles.first.path;
}

int cockpitScoreFlavorMatchingBundlePath(String path, String? flavor) {
  if (flavor == null || flavor.isEmpty) {
    return 0;
  }
  return path.toLowerCase().contains(flavor.toLowerCase()) ? 100 : 0;
}

Future<String> cockpitResolveIosBundleId({
  required String appBundlePath,
}) {
  return cockpitResolveAppleBundleId(
    appBundlePath: appBundlePath,
    infoPlistPathSegments: const <String>['Info.plist'],
    platformLabel: 'iOS',
  );
}

Future<String> cockpitResolveMacosBundleId({
  required String appBundlePath,
}) {
  return cockpitResolveAppleBundleId(
    appBundlePath: appBundlePath,
    infoPlistPathSegments: const <String>['Contents', 'Info.plist'],
    platformLabel: 'macOS',
  );
}

Future<String> cockpitResolveAppleBundleId({
  required String appBundlePath,
  required List<String> infoPlistPathSegments,
  required String platformLabel,
}) async {
  final pathContext = cockpitSessionPathContext(appBundlePath);
  final result = await Process.run('/usr/libexec/PlistBuddy', <String>[
    '-c',
    'Print :CFBundleIdentifier',
    pathContext.joinAll(<String>[appBundlePath, ...infoPlistPathSegments]),
  ]);
  if (result.exitCode != 0) {
    throw StateError(
      'Unable to resolve $platformLabel bundle identifier from '
      '$appBundlePath: ${result.stderr ?? result.stdout}',
    );
  }
  return '${result.stdout}'.trim();
}

List<Directory> _findTopLevelAppBundles({
  required Directory searchRoot,
  required p.Context pathContext,
}) {
  final appBundles = searchRoot
      .listSync(recursive: true, followLinks: false)
      .whereType<Directory>()
      .where(
        (entry) => pathContext.extension(entry.path).toLowerCase() == '.app',
      )
      .toList(growable: true)
    ..sort((left, right) {
      final leftPath = pathContext.normalize(left.path);
      final rightPath = pathContext.normalize(right.path);
      final depthCompare = leftPath.length.compareTo(rightPath.length);
      if (depthCompare != 0) {
        return depthCompare;
      }
      return leftPath.compareTo(rightPath);
    });

  final topLevelBundles = <Directory>[];
  for (final bundle in appBundles) {
    final normalizedBundlePath = pathContext.normalize(bundle.path);
    final isNestedBundle = topLevelBundles.any(
      (candidate) => pathContext.isWithin(
        pathContext.normalize(candidate.path),
        normalizedBundlePath,
      ),
    );
    if (!isNestedBundle) {
      topLevelBundles.add(bundle);
    }
  }
  return topLevelBundles;
}
