import 'dart:math';

enum CockpitIdKind { root, workspace, checkout, project }

abstract interface class CockpitIdGenerator {
  String next(CockpitIdKind kind);
}

final class CockpitSecureIdGenerator implements CockpitIdGenerator {
  CockpitSecureIdGenerator({Random? random})
    : _random = random ?? Random.secure();

  final Random _random;

  @override
  String next(CockpitIdKind kind) {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    final token = bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${kind.name}_$token';
  }
}
