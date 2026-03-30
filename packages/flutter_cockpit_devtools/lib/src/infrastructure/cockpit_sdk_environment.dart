final class CockpitSdkEnvironment {
  const CockpitSdkEnvironment({
    this.dartExecutable = 'dart',
    this.flutterExecutable = 'flutter',
  });

  final String dartExecutable;
  final String flutterExecutable;

  factory CockpitSdkEnvironment.fromEnvironment(
    Map<String, String> environment,
  ) {
    return CockpitSdkEnvironment(
      dartExecutable: environment['DART'] ?? environment['DART_BIN'] ?? 'dart',
      flutterExecutable:
          environment['FLUTTER'] ?? environment['FLUTTER_BIN'] ?? 'flutter',
    );
  }
}
