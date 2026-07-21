import 'dart:convert';
import 'dart:math';

enum CockpitIdKind { root, workspace, checkout, project, lease, cleanup }

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

abstract interface class CockpitTokenGenerator {
  String nextToken({int byteLength = 32});
}

final class CockpitSecureTokenGenerator implements CockpitTokenGenerator {
  CockpitSecureTokenGenerator({Random? random})
    : _random = random ?? Random.secure();

  final Random _random;

  @override
  String nextToken({int byteLength = 32}) {
    if (byteLength < 16 || byteLength > 64) {
      throw ArgumentError.value(byteLength, 'byteLength');
    }
    final bytes = List<int>.generate(byteLength, (_) => _random.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }
}
