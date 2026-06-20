import 'package:cockpit/cockpit.dart';
import 'package:test/test.dart';

void main() {
  group('CockpitSensitiveDataRedactor', () {
    test('redacts sensitive keys recursively without changing safe data', () {
      final redacted = const CockpitSensitiveDataRedactor().redact(
        const <String, Object?>{
          'Authorization': 'Bearer abc',
          'safe': 'visible',
          'nested': <String, Object?>{
            'accessToken': 'token-value',
            'cookie': 'sid=abc',
            'count': 3,
          },
          'items': <Object?>[
            <String, Object?>{'PASSWORD': 'pw', 'name': 'alice'},
            <String, Object?>{'secretKey': 'secret', 'enabled': true},
          ],
        },
      );

      final root = redacted as Map<String, Object?>;
      expect(root['Authorization'], CockpitSensitiveDataRedactor.redactedValue);
      expect(root['safe'], 'visible');

      final nested = root['nested']! as Map<String, Object?>;
      expect(nested['accessToken'], CockpitSensitiveDataRedactor.redactedValue);
      expect(nested['cookie'], CockpitSensitiveDataRedactor.redactedValue);
      expect(nested['count'], 3);

      final items = root['items']! as List<Object?>;
      expect(
        (items.first! as Map<String, Object?>)['PASSWORD'],
        CockpitSensitiveDataRedactor.redactedValue,
      );
      expect((items.first! as Map<String, Object?>)['name'], 'alice');
      expect(
        (items.last! as Map<String, Object?>)['secretKey'],
        CockpitSensitiveDataRedactor.redactedValue,
      );
      expect((items.last! as Map<String, Object?>)['enabled'], isTrue);
    });
  });
}
