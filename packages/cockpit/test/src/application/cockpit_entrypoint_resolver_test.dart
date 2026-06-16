import 'package:cockpit/src/application/cockpit_application_service_exception.dart';
import 'package:cockpit/src/application/cockpit_entrypoint_resolver.dart';
import 'package:test/test.dart';

void main() {
  test('prefers cockpit/main.dart when target is omitted', () {
    final resolver = CockpitEntrypointResolver(
      exists: (path) =>
          path == '/workspace/examples/cockpit_demo/cockpit/main.dart',
    );

    final target = resolver.resolve(
      projectDir: '/workspace/examples/cockpit_demo',
    );

    expect(target, 'cockpit/main.dart');
  });

  test('falls back to lib/main.dart when cockpit entrypoint is absent', () {
    final resolver = CockpitEntrypointResolver(
      exists: (path) =>
          path == '/workspace/examples/cockpit_demo/lib/main.dart',
    );

    final target = resolver.resolve(
      projectDir: '/workspace/examples/cockpit_demo',
    );

    expect(target, 'lib/main.dart');
  });

  test('rejects an explicit target that does not exist', () {
    final resolver = CockpitEntrypointResolver(exists: (_) => false);

    expect(
      () => resolver.resolve(
        projectDir: '/workspace/examples/cockpit_demo',
        target: 'custom/main.dart',
      ),
      throwsA(
        isA<CockpitApplicationServiceException>()
            .having((error) => error.code, 'code', 'missingTargetEntrypoint')
            .having(
              (error) => error.message,
              'message',
              contains('custom/main.dart'),
            ),
      ),
    );
  });
}
