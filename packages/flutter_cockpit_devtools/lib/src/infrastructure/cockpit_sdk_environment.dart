import 'dart:io';

import 'package:path/path.dart' as p;

final class CockpitSdkEnvironment {
  const CockpitSdkEnvironment({
    this.dartExecutable = 'dart',
    this.flutterExecutable = 'flutter',
  });

  final String dartExecutable;
  final String flutterExecutable;

  factory CockpitSdkEnvironment.current({
    Map<String, String>? environment,
    bool? isWindows,
  }) {
    return CockpitSdkEnvironment.fromEnvironment(
      environment ?? Platform.environment,
      isWindows: isWindows,
      currentResolvedExecutable: Platform.resolvedExecutable,
    );
  }

  factory CockpitSdkEnvironment.fromEnvironment(
    Map<String, String> environment, {
    bool? isWindows,
    String? currentResolvedExecutable,
  }) {
    final windows = isWindows ?? Platform.isWindows;
    final pathContext = p.Context(
      style: windows ? p.Style.windows : p.Style.posix,
    );
    final flutterRoot = _readFirst(environment, const <String>[
      'FLUTTER_ROOT',
      'FLUTTER_SDK',
    ]);
    final dartRoot = _readFirst(environment, const <String>[
      'DART_ROOT',
      'DART_SDK',
    ]);
    final currentDartExecutable = _currentDartExecutable(
      currentResolvedExecutable,
      windows: windows,
      pathContext: pathContext,
    );
    final currentFlutterRoot = _flutterRootFromBundledDartExecutable(
      currentDartExecutable,
      pathContext: pathContext,
    );
    return CockpitSdkEnvironment(
      dartExecutable:
          _readFirst(environment, const <String>['DART', 'DART_BIN']) ??
          _dartExecutableFromRoot(
            dartRoot,
            windows: windows,
            pathContext: pathContext,
          ) ??
          _flutterBundledDartExecutable(
            flutterRoot,
            windows: windows,
            pathContext: pathContext,
          ) ??
          currentDartExecutable ??
          _defaultDartExecutable(windows),
      flutterExecutable:
          _readFirst(environment, const <String>['FLUTTER', 'FLUTTER_BIN']) ??
          _flutterExecutableFromRoot(
            flutterRoot,
            windows: windows,
            pathContext: pathContext,
          ) ??
          _flutterExecutableFromRoot(
            currentFlutterRoot,
            windows: windows,
            pathContext: pathContext,
          ) ??
          _defaultFlutterExecutable(windows),
    );
  }
}

String? _readFirst(Map<String, String> environment, List<String> keys) {
  for (final key in keys) {
    final value = environment[key]?.trim();
    if (value != null && value.isNotEmpty) {
      return value;
    }
  }
  return null;
}

String _defaultDartExecutable(bool windows) => windows ? 'dart.exe' : 'dart';

String _defaultFlutterExecutable(bool windows) =>
    windows ? 'flutter.bat' : 'flutter';

String? _dartExecutableFromRoot(
  String? dartRoot, {
  required bool windows,
  required p.Context pathContext,
}) {
  if (dartRoot == null) {
    return null;
  }
  return pathContext.normalize(
    pathContext.join(dartRoot, 'bin', _defaultDartExecutable(windows)),
  );
}

String? _flutterBundledDartExecutable(
  String? flutterRoot, {
  required bool windows,
  required p.Context pathContext,
}) {
  if (flutterRoot == null) {
    return null;
  }
  return pathContext.normalize(
    pathContext.join(
      flutterRoot,
      'bin',
      'cache',
      'dart-sdk',
      'bin',
      _defaultDartExecutable(windows),
    ),
  );
}

String? _flutterExecutableFromRoot(
  String? flutterRoot, {
  required bool windows,
  required p.Context pathContext,
}) {
  if (flutterRoot == null) {
    return null;
  }
  return pathContext.normalize(
    pathContext.join(flutterRoot, 'bin', _defaultFlutterExecutable(windows)),
  );
}

String? _currentDartExecutable(
  String? currentResolvedExecutable, {
  required bool windows,
  required p.Context pathContext,
}) {
  final executable = currentResolvedExecutable?.trim();
  if (executable == null || executable.isEmpty) {
    return null;
  }
  final expectedName = _defaultDartExecutable(windows).toLowerCase();
  if (pathContext.basename(executable).toLowerCase() != expectedName) {
    return null;
  }
  return pathContext.normalize(executable);
}

String? _flutterRootFromBundledDartExecutable(
  String? dartExecutable, {
  required p.Context pathContext,
}) {
  if (dartExecutable == null) {
    return null;
  }
  final binDir = pathContext.dirname(dartExecutable);
  final dartSdkDir = pathContext.basename(pathContext.dirname(binDir));
  final cacheDir = pathContext.basename(
    pathContext.dirname(pathContext.dirname(binDir)),
  );
  final flutterBinDir = pathContext.basename(
    pathContext.dirname(pathContext.dirname(pathContext.dirname(binDir))),
  );
  if (dartSdkDir != 'dart-sdk' ||
      cacheDir != 'cache' ||
      flutterBinDir != 'bin') {
    return null;
  }
  return pathContext.dirname(
    pathContext.dirname(pathContext.dirname(pathContext.dirname(binDir))),
  );
}
