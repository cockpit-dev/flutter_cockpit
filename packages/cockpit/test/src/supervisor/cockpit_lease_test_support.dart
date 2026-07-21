import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:cockpit/src/foundation/cockpit_home.dart';
import 'package:cockpit/src/foundation/cockpit_ids.dart';
import 'package:cockpit/src/foundation/cockpit_locked_json_store.dart';
import 'package:cockpit/src/foundation/cockpit_permissions.dart';
import 'package:cockpit/src/infrastructure/cockpit_monotonic_clock.dart';
import 'package:cockpit/src/supervisor/cockpit_lease_registry.dart';
import 'package:cockpit/src/supervisor/cockpit_lease_support.dart';
import 'package:cockpit_protocol/cockpit_protocol.dart';
import 'package:path/path.dart' as p;

final class CockpitLeaseTestFixture {
  CockpitLeaseTestFixture._({
    required this.temporary,
    required this.paths,
    required this.registry,
    required this.cleanup,
    required this.clock,
    required this.authority,
    required this.hardener,
    required this.syncer,
  });

  final Directory temporary;
  final CockpitHomePaths paths;
  final CockpitLeaseRegistry registry;
  final TestLeaseCleanupProbe cleanup;
  final CockpitMonotonicClock clock;
  final TestLeaseWorkspaceAuthority authority;
  final CockpitPermissionHardener hardener;
  final CockpitDirectorySyncer syncer;

  static Future<CockpitLeaseTestFixture> create({
    CockpitMonotonicClock? clock,
    Map<CockpitLeaseResourceKind, CockpitLeaseCleanupProbe>? probes,
  }) async {
    final temporary = await Directory.systemTemp.createTemp('cockpit-leases-');
    final hardener = Platform.isWindows
        ? const CockpitWindowsInheritedAclPermissionHardener()
        : const CockpitPosixPermissionHardener();
    const syncer = TestDirectorySyncer();
    final paths = await CockpitHome(
      paths: CockpitHomePaths(p.join(temporary.path, 'home')),
      permissionHardener: hardener,
    ).initialize();
    final cleanup = TestLeaseCleanupProbe();
    final cleanupMap = <CockpitLeaseResourceKind, CockpitLeaseCleanupProbe>{
      for (final kind in CockpitLeaseResourceKind.values) kind: cleanup,
      ...?probes,
    };
    final authority = TestLeaseWorkspaceAuthority();
    final resolvedClock = clock ?? CockpitSystemMonotonicClock();
    final registry = CockpitLeaseRegistry.create(
      paths: paths,
      permissionHardener: hardener,
      directorySyncer: syncer,
      workspaceAuthority: authority,
      cleanupProbes: CockpitLeaseCleanupProbeMap(cleanupMap),
      idGenerator: TestLeaseIdGenerator(),
      clock: resolvedClock,
      pollInterval: const Duration(milliseconds: 5),
      cleanupTimeout: const Duration(seconds: 5),
      cleanupClaimGrace: const Duration(seconds: 1),
    );
    return CockpitLeaseTestFixture._(
      temporary: temporary,
      paths: paths,
      registry: registry,
      cleanup: cleanup,
      clock: resolvedClock,
      authority: authority,
      hardener: hardener,
      syncer: syncer,
    );
  }

  CockpitLeaseRegistry reopen({
    CockpitLeaseCleanupProbeResolver? cleanupProbes,
  }) => CockpitLeaseRegistry.create(
    paths: paths,
    permissionHardener: hardener,
    directorySyncer: syncer,
    workspaceAuthority: authority,
    cleanupProbes:
        cleanupProbes ??
        CockpitLeaseCleanupProbeMap(
          <CockpitLeaseResourceKind, CockpitLeaseCleanupProbe>{
            for (final kind in CockpitLeaseResourceKind.values) kind: cleanup,
          },
        ),
    idGenerator: TestLeaseIdGenerator(start: 1000),
    clock: clock,
    pollInterval: const Duration(milliseconds: 5),
    cleanupTimeout: const Duration(seconds: 5),
    cleanupClaimGrace: const Duration(seconds: 1),
  );

  Future<void> dispose() => temporary.delete(recursive: true);
}

final class TestLeaseWorkspaceAuthority
    implements CockpitLeaseWorkspaceAuthority {
  final Map<String, String> roots = <String, String>{
    'workspaceA': 'rootA',
    'workspaceB': 'rootB',
  };

  @override
  Future<CockpitLeaseWorkspaceScope> resolveActive(String workspaceId) async {
    final rootId = roots[workspaceId];
    if (rootId == null) {
      throw const CockpitLeaseException(
        code: 'workspaceNotActive',
        message: 'Test workspace is not active.',
      );
    }
    return CockpitLeaseWorkspaceScope(workspaceId: workspaceId, rootId: rootId);
  }
}

final class TestLeaseCleanupProbe implements CockpitLeaseCleanupProbe {
  final List<CockpitLeaseCleanupContext> contexts =
      <CockpitLeaseCleanupContext>[];
  final Queue<Future<CockpitLeaseCleanupResult>> _results =
      Queue<Future<CockpitLeaseCleanupResult>>();

  void enqueue(Future<CockpitLeaseCleanupResult> result) {
    _results.add(result);
  }

  @override
  Future<CockpitLeaseCleanupResult> cleanupAndVerify(
    CockpitLeaseCleanupContext context,
  ) {
    contexts.add(context);
    return _results.isEmpty
        ? Future<CockpitLeaseCleanupResult>.value(
            const CockpitLeaseCleanupResult.restored(),
          )
        : _results.removeFirst();
  }
}

final class TestLeaseIdGenerator implements CockpitIdGenerator {
  TestLeaseIdGenerator({int start = 0}) : _next = start;

  int _next;

  @override
  String next(CockpitIdKind kind) => '${kind.name}_${_next++}';
}

final class TestDirectorySyncer implements CockpitDirectorySyncer {
  const TestDirectorySyncer();

  @override
  Future<void> sync(String directoryPath) async {}
}

final class TestLeaseClock implements CockpitMonotonicClock {
  TestLeaseClock({DateTime? origin})
    : _origin = origin ?? DateTime.utc(2026, 7, 21);

  final DateTime _origin;
  Duration _elapsed = Duration.zero;
  final List<_TestClockWaiter> _waiters = <_TestClockWaiter>[];

  @override
  Duration get elapsed => _elapsed;

  @override
  DateTime get utcNow => _origin.add(_elapsed);

  @override
  Future<void> delay(Duration duration) {
    if (duration <= Duration.zero) return Future<void>.value();
    final completer = Completer<void>();
    _waiters.add(_TestClockWaiter(_elapsed + duration, completer));
    return completer.future;
  }

  void advance(Duration duration) {
    if (duration.isNegative) throw ArgumentError.value(duration, 'duration');
    _elapsed += duration;
    for (final waiter in _waiters.toList()) {
      if (waiter.deadline <= _elapsed) {
        _waiters.remove(waiter);
        waiter.completer.complete();
      }
    }
  }
}

final class _TestClockWaiter {
  const _TestClockWaiter(this.deadline, this.completer);

  final Duration deadline;
  final Completer<void> completer;
}

CockpitLeaseRequest leaseRequest({
  required String key,
  required String resourceId,
  String workspaceId = 'workspaceA',
  String holderId = 'runA',
  CockpitLeaseResourceKind resourceKind = CockpitLeaseResourceKind.device,
  int waitTimeoutMs = 30000,
  int ttlMs = 30000,
}) => CockpitLeaseRequest(
  workspaceId: workspaceId,
  resourceKind: resourceKind,
  resourceId: resourceId,
  holderId: holderId,
  idempotencyKey: CockpitIdempotencyKey(key),
  waitTimeoutMs: waitTimeoutMs,
  ttlMs: ttlMs,
);

CockpitFailure testLeaseFailure(String code) => CockpitFailure(
  primary: CockpitApiError(
    code: code,
    category: CockpitErrorCategory.resource,
    message: 'Test cleanup failure.',
    retryable: true,
    responsibleLayer: CockpitResponsibleLayer.supervisor,
  ),
);

Future<void> waitForLeaseCondition(
  Future<bool> Function() condition, {
  Duration timeout = const Duration(seconds: 3),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!await condition()) {
    if (DateTime.now().isAfter(deadline)) {
      throw TimeoutException('Lease test condition was not reached.', timeout);
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}
