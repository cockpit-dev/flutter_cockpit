import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:test/test.dart';

void main() {
  test('timestamp tokens are readable fixed-width UTC path tokens', () {
    expect(
      cockpitSortableTimestampToken(DateTime.utc(2026, 5, 30, 6, 3, 4, 5, 6)),
      '20260530T060304005006Z',
    );
    expect(
      cockpitSortableTimestampToken(DateTime.utc(2026, 5, 30, 6, 3, 4)),
      '20260530T060304000000Z',
    );
    expect(
      cockpitSortableTimestampToken(DateTime(2026, 5, 30, 14, 3, 4)),
      isNot(anyOf(contains(':'), contains(' '), contains('/'))),
    );
  });

  test('timestamp tokens sort lexically in chronological order', () {
    final names = <String>[
      cockpitSortableTimestampToken(DateTime.utc(2026, 5, 30, 6, 3, 4, 0, 1)),
      cockpitSortableTimestampToken(DateTime.utc(2026, 5, 30, 6, 3, 4)),
      cockpitSortableTimestampToken(DateTime.utc(2026, 5, 30, 6, 3, 4, 1)),
      cockpitSortableTimestampToken(DateTime.utc(2026, 5, 30, 6, 3, 5)),
    ];

    expect(names.toList()..sort(), <String>[
      '20260530T060304000000Z',
      '20260530T060304000001Z',
      '20260530T060304001000Z',
      '20260530T060305000000Z',
    ]);
  });

  test('artifact name tokens preserve readable words and stay path-safe', () {
    expect(
      cockpitSanitizeArtifactNameToken(
        '../Team Login: Acceptance',
        fallback: 'capture',
        lowercase: true,
      ),
      'team_login_acceptance',
    );
    expect(
      cockpitSanitizeArtifactNameToken('...', fallback: 'capture'),
      'capture',
    );
    expect(
      cockpitSanitizeArtifactNameToken('...', fallback: '../Capture Default'),
      'Capture_Default',
    );
  });
}
