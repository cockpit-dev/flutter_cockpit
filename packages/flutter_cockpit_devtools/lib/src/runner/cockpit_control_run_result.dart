import 'package:flutter_cockpit/flutter_cockpit.dart';

final class CockpitControlRunResult {
  CockpitControlRunResult({
    required this.bundle,
    Map<String, List<int>> artifactPayloads = const <String, List<int>>{},
    Map<String, String> artifactSourcePaths = const <String, String>{},
  })  : artifactPayloads = Map.unmodifiable(
          artifactPayloads.map(
            (path, bytes) => MapEntry(path, List<int>.unmodifiable(bytes)),
          ),
        ),
        artifactSourcePaths = Map.unmodifiable(artifactSourcePaths);

  final CockpitContextBundle bundle;
  final Map<String, List<int>> artifactPayloads;
  final Map<String, String> artifactSourcePaths;
}
