import 'dart:async';

import 'package:dart_mcp/server.dart';
import 'package:flutter_cockpit_devtools/src/mcp/core/cockpit_mcp_roots_tracker.dart';
import 'package:test/test.dart';

void main() {
  test('uses fallback roots when native roots are unsupported', () async {
    final tracker = CockpitMcpRootsTracker();

    await tracker.bind(
      clientSupportsRoots: false,
      readRoots: () async => const <Root>[],
    );
    tracker.addFallbackRoots(
      <Root>[Root(uri: 'file:///workspace', name: 'workspace')],
    );

    expect(tracker.fallbackActive, isTrue);
    expect(tracker.effectiveRoots, hasLength(1));
    expect(tracker.effectiveRoots.single.uri, 'file:///workspace');
  });

  test('refreshes native roots when the client reports roots support', () async {
    final tracker = CockpitMcpRootsTracker();
    final controller = StreamController<void>.broadcast();

    var currentRoots = <Root>[
      Root(uri: 'file:///workspace/a', name: 'a'),
    ];

    await tracker.bind(
      clientSupportsRoots: true,
      readRoots: () async => currentRoots,
      rootsChanged: controller.stream,
    );

    expect(tracker.fallbackActive, isFalse);
    expect(tracker.effectiveRoots.single.uri, 'file:///workspace/a');

    currentRoots = <Root>[
      Root(uri: 'file:///workspace/b', name: 'b'),
    ];
    controller.add(null);
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(tracker.effectiveRoots.single.uri, 'file:///workspace/b');
    await tracker.dispose();
    await controller.close();
  });
}
