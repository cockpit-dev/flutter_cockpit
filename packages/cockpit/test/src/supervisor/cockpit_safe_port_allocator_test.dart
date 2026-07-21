import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cockpit/src/foundation/cockpit_ids.dart';
import 'package:cockpit/src/supervisor/cockpit_lease_registry.dart';
import 'package:cockpit/src/supervisor/cockpit_lease_registry_activity.dart';
import 'package:cockpit/src/supervisor/cockpit_lease_support.dart';
import 'package:cockpit/src/supervisor/cockpit_loopback_port_cleanup_probe.dart';
import 'package:cockpit/src/supervisor/cockpit_port_models.dart';
import 'package:cockpit/src/supervisor/cockpit_safe_port_allocator.dart';
import 'package:cockpit_protocol/cockpit_protocol.dart';
import 'package:test/test.dart';

import 'cockpit_lease_test_support.dart';

void main() {
  group('safe loopback port allocator', () {
    test(
      'holds a real ephemeral socket and replays reservations idempotently',
      () async {
        final fixture = await _portFixture();
        addTearDown(fixture.dispose);
        final allocator = _allocator(fixture);
        final reservation = await allocator.reserve(
          workspaceId: 'workspaceA',
          holderId: 'runA',
          idempotencyKey: CockpitIdempotencyKey('port.reserve'),
        );
        final replay = await allocator.reserve(
          workspaceId: 'workspaceA',
          holderId: 'runA',
          idempotencyKey: CockpitIdempotencyKey('port.reserve'),
        );
        expect(identical(replay, reservation), isTrue);
        await expectLater(
          allocator.reserve(
            workspaceId: 'workspaceA',
            holderId: 'runB',
            idempotencyKey: CockpitIdempotencyKey('port.reserve'),
          ),
          throwsLease('idempotencyConflict'),
        );
        await expectLater(
          allocator.reserve(
            workspaceId: 'workspaceA',
            holderId: 'runA',
            idempotencyKey: CockpitIdempotencyKey('port.reserve'),
            ttl: const Duration(seconds: 45),
          ),
          throwsLease('idempotencyConflict'),
        );
        await expectLater(
          ServerSocket.bind(
            InternetAddress.loopbackIPv4,
            reservation.port,
            shared: false,
          ),
          throwsA(isA<SocketException>()),
        );

        expect((await reservation.release()).state, CockpitLeaseState.released);
        final rebound = await ServerSocket.bind(
          InternetAddress.loopbackIPv4,
          reservation.port,
          shared: false,
        );
        await rebound.close();
        await expectLater(
          allocator.reserve(
            workspaceId: 'workspaceA',
            holderId: 'runA',
            idempotencyKey: CockpitIdempotencyKey('port.reserve'),
          ),
          throwsLease('portReservationReleased'),
        );
      },
    );

    test(
      'replays the durable port and handoff token after allocator restart',
      () async {
        final fixture = await _portFixture();
        addTearDown(fixture.dispose);
        late ServerSocket abandonedSocket;
        final original =
            await _allocator(
              fixture,
              bindEphemeral: () async {
                abandonedSocket = await cockpitBindEphemeralLoopback();
                return abandonedSocket;
              },
            ).reserve(
              workspaceId: 'workspaceA',
              holderId: 'runA',
              idempotencyKey: CockpitIdempotencyKey('port.restart-replay'),
            );
        final originalPort = original.port;
        final originalLeaseId = original.lease.leaseId;
        await abandonedSocket.close();

        final replayed =
            await _allocator(
              fixture,
              tokenGenerator: const _FixedPortTokenGenerator(_tokenB),
            ).reserve(
              workspaceId: 'workspaceA',
              holderId: 'runA',
              idempotencyKey: CockpitIdempotencyKey('port.restart-replay'),
            );
        expect(replayed.port, originalPort);
        expect(replayed.lease.leaseId, originalLeaseId);
        expect(
          await fixture.registry.list(resourceId: replayed.lease.resourceId),
          hasLength(1),
        );

        final owner = _JsonLinePortOwner(
          expected: _expectedOwner(),
          wrongToken: false,
        );
        addTearDown(owner.close);
        final verified = await replayed.handoff(
          binder: owner,
          ownerProbe: owner,
          expectedOwner: _expectedOwner(),
        );
        expect(owner.handoffToken, _tokenA);
        await owner.close();
        await verified.release();
      },
    );

    test('quarantines a reserved port lost during restart', () async {
      final fixture = await _portFixture();
      addTearDown(fixture.dispose);
      late ServerSocket abandonedSocket;
      final original =
          await _allocator(
            fixture,
            bindEphemeral: () async {
              abandonedSocket = await cockpitBindEphemeralLoopback();
              return abandonedSocket;
            },
          ).reserve(
            workspaceId: 'workspaceA',
            holderId: 'runA',
            idempotencyKey: CockpitIdempotencyKey('port.restart-conflict'),
          );
      await abandonedSocket.close();
      final conflictingOwner = await ServerSocket.bind(
        InternetAddress.loopbackIPv4,
        original.port,
        shared: false,
      );
      addTearDown(conflictingOwner.close);

      await expectLater(
        _allocator(fixture).reserve(
          workspaceId: 'workspaceA',
          holderId: 'runA',
          idempotencyKey: CockpitIdempotencyKey('port.restart-conflict'),
        ),
        throwsLease('portReservationUnavailable'),
      );

      expect(
        (await fixture.registry.get(original.lease.leaseId)).state,
        CockpitLeaseState.quarantined,
      );
    });

    test('cached replay revalidates active workspace authority', () async {
      final fixture = await _portFixture();
      addTearDown(fixture.dispose);
      final allocator = _allocator(fixture);
      final reservation = await allocator.reserve(
        workspaceId: 'workspaceA',
        holderId: 'runA',
        idempotencyKey: CockpitIdempotencyKey('port.cached-authority'),
      );
      fixture.authority.roots.remove('workspaceA');
      await expectLater(
        allocator.reserve(
          workspaceId: 'workspaceA',
          holderId: 'runA',
          idempotencyKey: CockpitIdempotencyKey('port.cached-authority'),
        ),
        throwsLease('workspaceNotActive'),
      );
      fixture.authority.roots['workspaceA'] = 'rootA';
      await reservation.release();
    });

    test(
      'workspace drain waits for a supervisor-owned reservation release',
      () async {
        final fixture = await _portFixture();
        addTearDown(fixture.dispose);
        final reservation = await _allocator(fixture).reserve(
          workspaceId: 'workspaceA',
          holderId: 'runA',
          idempotencyKey: CockpitIdempotencyKey('port.workspace-drain'),
        );
        var completed = false;
        final drain =
            CockpitLeaseRegistryActivityController(leases: fixture.registry)
                .drainWorkspaces(<String>{
                  'workspaceA',
                }, const Duration(seconds: 2))
                .then((_) => completed = true);
        await Future<void>.delayed(const Duration(milliseconds: 30));
        expect(completed, isFalse);
        await expectLater(
          ServerSocket.bind(
            InternetAddress.loopbackIPv4,
            reservation.port,
            shared: false,
          ),
          throwsA(isA<SocketException>()),
        );

        await reservation.release();
        await drain;
        expect(
          (await fixture.registry.get(reservation.lease.leaseId)).state,
          CockpitLeaseState.released,
        );
        final rebound = await ServerSocket.bind(
          InternetAddress.loopbackIPv4,
          reservation.port,
          shared: false,
        );
        await rebound.close();
      },
    );

    test(
      'rejects durable replay after workspace authority is retired',
      () async {
        final fixture = await _portFixture();
        addTearDown(fixture.dispose);
        late ServerSocket abandonedSocket;
        final original =
            await _allocator(
              fixture,
              bindEphemeral: () async {
                abandonedSocket = await cockpitBindEphemeralLoopback();
                return abandonedSocket;
              },
            ).reserve(
              workspaceId: 'workspaceA',
              holderId: 'runA',
              idempotencyKey: CockpitIdempotencyKey('port.retirement-race'),
            );
        await abandonedSocket.close();

        final fenceEntered = Completer<void>();
        final releaseFence = Completer<void>();
        final fence = fixture.registry.withAdmissionFence(
          <String>{'rootA'},
          <String>{'workspaceA'},
          () async {
            fenceEntered.complete();
            await releaseFence.future;
          },
        );
        await fenceEntered.future;
        var replayCompleted = false;
        final replay = _allocator(fixture)
            .reserve(
              workspaceId: 'workspaceA',
              holderId: 'runA',
              idempotencyKey: CockpitIdempotencyKey('port.retirement-race'),
            )
            .whenComplete(() => replayCompleted = true);
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(replayCompleted, isFalse);

        final replayFailure = expectLater(
          replay,
          throwsLease('workspaceNotActive'),
        );
        fixture.authority.roots.remove('workspaceA');
        releaseFence.complete();
        await fence;
        await replayFailure;
        final rebound = await ServerSocket.bind(
          InternetAddress.loopbackIPv4,
          original.port,
          shared: false,
        );
        await rebound.close();
      },
    );

    test(
      'hands off only after exact process and session owner verification',
      () async {
        final fixture = await _portFixture();
        addTearDown(fixture.dispose);
        final reservation = await _allocator(fixture).reserve(
          workspaceId: 'workspaceA',
          holderId: 'runA',
          idempotencyKey: CockpitIdempotencyKey('port.handoff'),
        );
        final owner = _JsonLinePortOwner(
          expected: _expectedOwner(),
          wrongToken: false,
        );
        addTearDown(owner.close);

        final verified = await reservation.handoff(
          binder: owner,
          ownerProbe: owner,
          expectedOwner: _expectedOwner(),
        );
        expect(verified.port, reservation.port);
        expect(reservation.state, CockpitPortReservationState.handedOff);
        await expectLater(
          ServerSocket.bind(
            InternetAddress.loopbackIPv4,
            verified.port,
            shared: false,
          ),
          throwsA(isA<SocketException>()),
        );

        final recovered = await _allocator(fixture).reserve(
          workspaceId: 'workspaceA',
          holderId: 'runA',
          idempotencyKey: CockpitIdempotencyKey('port.handoff'),
        );
        expect(recovered.state, CockpitPortReservationState.recoveryPending);
        final recoveredVerified = await recovered.handoff(
          binder: owner,
          ownerProbe: owner,
          expectedOwner: _expectedOwner(),
        );
        expect(recoveredVerified.lease.leaseId, verified.lease.leaseId);
        expect(owner.bindCount, 1);

        await owner.close();
        expect(
          (await recoveredVerified.release()).state,
          CockpitLeaseState.released,
        );
        expect(recovered.state, CockpitPortReservationState.released);
      },
    );

    test('quarantines a changed owner after handed-off restart', () async {
      final fixture = await _portFixture();
      addTearDown(fixture.dispose);
      final reservation = await _allocator(fixture).reserve(
        workspaceId: 'workspaceA',
        holderId: 'runA',
        idempotencyKey: CockpitIdempotencyKey('port.owner-restart-mismatch'),
      );
      final owner = _JsonLinePortOwner(
        expected: _expectedOwner(),
        wrongToken: false,
      );
      addTearDown(owner.close);
      await reservation.handoff(
        binder: owner,
        ownerProbe: owner,
        expectedOwner: _expectedOwner(),
      );
      owner.wrongToken = true;

      final recovered = await _allocator(fixture).reserve(
        workspaceId: 'workspaceA',
        holderId: 'runA',
        idempotencyKey: CockpitIdempotencyKey('port.owner-restart-mismatch'),
      );
      await expectLater(
        recovered.handoff(
          binder: owner,
          ownerProbe: owner,
          expectedOwner: _expectedOwner(),
        ),
        throwsLease('portOwnerMismatch'),
      );
      expect(recovered.state, CockpitPortReservationState.quarantined);
      expect(
        (await fixture.registry.get(recovered.lease.leaseId)).state,
        CockpitLeaseState.quarantined,
      );
    });

    test('continues a crash-persisted handingOff phase safely', () async {
      final fixture = await _portFixture();
      addTearDown(fixture.dispose);
      late ServerSocket abandonedSocket;
      final reservation =
          await _allocator(
            fixture,
            bindEphemeral: () async {
              abandonedSocket = await cockpitBindEphemeralLoopback();
              return abandonedSocket;
            },
          ).reserve(
            workspaceId: 'workspaceA',
            holderId: 'runA',
            idempotencyKey: CockpitIdempotencyKey('port.handing-off-crash'),
          );
      await fixture.registry.beginPortHandoff(
        leaseId: reservation.lease.leaseId,
        holderId: reservation.lease.holderId,
        expectedOwner: _durableOwner(),
      );
      await abandonedSocket.close();

      final recovered = await _allocator(fixture).reserve(
        workspaceId: 'workspaceA',
        holderId: 'runA',
        idempotencyKey: CockpitIdempotencyKey('port.handing-off-crash'),
      );
      expect(recovered.state, CockpitPortReservationState.recoveryPending);
      final owner = _JsonLinePortOwner(
        expected: _expectedOwner(),
        wrongToken: false,
      );
      addTearDown(owner.close);
      final verified = await recovered.handoff(
        binder: owner,
        ownerProbe: owner,
        expectedOwner: _expectedOwner(),
      );
      expect(owner.bindCount, 1);
      await owner.close();
      await verified.release();
    });

    test('quarantines an unexpected owner until the port is healthy', () async {
      final fixture = await _portFixture();
      addTearDown(fixture.dispose);
      final reservation = await _allocator(fixture).reserve(
        workspaceId: 'workspaceA',
        holderId: 'runA',
        idempotencyKey: CockpitIdempotencyKey('port.mismatch'),
      );
      final owner = _JsonLinePortOwner(
        expected: _expectedOwner(),
        wrongToken: true,
      );
      addTearDown(owner.close);

      await expectLater(
        reservation.handoff(
          binder: owner,
          ownerProbe: owner,
          expectedOwner: _expectedOwner(),
        ),
        throwsLease('portOwnerMismatch'),
      );
      expect(reservation.state, CockpitPortReservationState.quarantined);
      expect(
        (await fixture.registry.get(reservation.lease.leaseId)).state,
        CockpitLeaseState.quarantined,
      );
      await owner.close();
      await fixture.registry.recoverResource(
        CockpitLeaseResourceKind.forwardedPort,
        reservation.lease.resourceId,
      );
      expect(
        (await fixture.registry.get(reservation.lease.leaseId)).state,
        CockpitLeaseState.released,
      );
    });

    test(
      'does not release a handed-off port while its owner is still bound',
      () async {
        final fixture = await _portFixture();
        addTearDown(fixture.dispose);
        final reservation = await _allocator(fixture).reserve(
          workspaceId: 'workspaceA',
          holderId: 'runA',
          idempotencyKey: CockpitIdempotencyKey('port.release-health'),
        );
        final owner = _JsonLinePortOwner(
          expected: _expectedOwner(),
          wrongToken: false,
        );
        addTearDown(owner.close);
        final verified = await reservation.handoff(
          binder: owner,
          ownerProbe: owner,
          expectedOwner: _expectedOwner(),
        );

        expect((await verified.release()).state, CockpitLeaseState.quarantined);
        expect(reservation.state, CockpitPortReservationState.quarantined);
        await owner.close();
        await fixture.registry.recoverResource(
          CockpitLeaseResourceKind.forwardedPort,
          reservation.lease.resourceId,
        );
        expect(
          (await fixture.registry.get(reservation.lease.leaseId)).state,
          CockpitLeaseState.released,
        );
      },
    );

    test(
      'never accepts a fixed driver port as cross-workspace identity',
      () async {
        final fixture = await _portFixture();
        addTearDown(fixture.dispose);
        final allocator = _allocator(fixture);
        final first = await allocator.reserve(
          workspaceId: 'workspaceA',
          holderId: 'runA',
          idempotencyKey: CockpitIdempotencyKey('port.workspaceA'),
        );
        final second = await allocator.reserve(
          workspaceId: 'workspaceB',
          holderId: 'runB',
          idempotencyKey: CockpitIdempotencyKey('port.workspaceB'),
        );
        expect(first.port, isNot(second.port));
        expect(first.lease.workspaceId, 'workspaceA');
        expect(second.lease.workspaceId, 'workspaceB');
        expect(first.lease.resourceId, 'loopback-v4:${first.port}');
        expect(second.lease.resourceId, 'loopback-v4:${second.port}');
        await first.release();
        await second.release();
      },
    );
  });
}

Future<CockpitLeaseTestFixture> _portFixture() =>
    CockpitLeaseTestFixture.create(
      probes: <CockpitLeaseResourceKind, CockpitLeaseCleanupProbe>{
        CockpitLeaseResourceKind.forwardedPort:
            const CockpitLoopbackPortCleanupProbe(),
      },
    );

CockpitSafePortAllocator _allocator(
  CockpitLeaseTestFixture fixture, {
  CockpitTokenGenerator tokenGenerator = const _FixedPortTokenGenerator(
    _tokenA,
  ),
  CockpitEphemeralLoopbackBinder bindEphemeral = cockpitBindEphemeralLoopback,
}) => CockpitSafePortAllocator(
  leases: fixture.registry,
  tokenGenerator: tokenGenerator,
  bindEphemeral: bindEphemeral,
  probeInterval: const Duration(milliseconds: 5),
);

CockpitExpectedPortOwner _expectedOwner() => CockpitExpectedPortOwner(
  ownerId: 'workerA',
  processId: pid,
  processStartIdentity: 'process-start-A',
  sessionId: 'sessionA',
);

CockpitDurablePortOwner _durableOwner() => CockpitDurablePortOwner(
  ownerId: 'workerA',
  processId: pid,
  processStartIdentity: 'process-start-A',
  sessionId: 'sessionA',
);

Matcher throwsLease(String code) => throwsA(
  isA<CockpitLeaseException>().having((error) => error.code, 'code', code),
);

final class _FixedPortTokenGenerator implements CockpitTokenGenerator {
  const _FixedPortTokenGenerator(this.token);

  final String token;

  @override
  String nextToken({int byteLength = 32}) => token;
}

final class _JsonLinePortOwner
    implements CockpitPortBinder, CockpitPortOwnerProbe {
  _JsonLinePortOwner({required this.expected, required this.wrongToken});

  final CockpitExpectedPortOwner expected;
  bool wrongToken;
  ServerSocket? _server;
  String? _handoffToken;
  int bindCount = 0;

  String? get handoffToken => _handoffToken;

  @override
  Future<void> bind(CockpitPortBindRequest request) async {
    bindCount += 1;
    _handoffToken = request.handoffToken;
    _server = await ServerSocket.bind(
      request.address,
      request.port,
      shared: false,
    );
    _server!.listen(_serve);
  }

  Future<void> _serve(Socket socket) async {
    try {
      await utf8.decoder.bind(socket).transform(const LineSplitter()).first;
      socket.writeln(
        jsonEncode(<String, Object?>{
          'ownerId': expected.ownerId,
          'processId': expected.processId,
          'processStartIdentity': expected.processStartIdentity,
          'sessionId': expected.sessionId,
          'handoffToken': wrongToken ? _tokenB : _handoffToken,
        }),
      );
      await socket.flush();
    } finally {
      await socket.close();
    }
  }

  @override
  Future<CockpitObservedPortOwner?> inspect({
    required InternetAddress address,
    required int port,
    required DateTime deadline,
  }) async {
    final socket = await Socket.connect(address, port);
    try {
      socket.writeln('cockpit.port-owner.probe/v2');
      await socket.flush();
      final line = await utf8.decoder
          .bind(socket)
          .transform(const LineSplitter())
          .first;
      final json = jsonDecode(line) as Map<String, Object?>;
      return CockpitObservedPortOwner(
        ownerId: json['ownerId']! as String,
        processId: json['processId']! as int,
        processStartIdentity: json['processStartIdentity']! as String,
        sessionId: json['sessionId']! as String,
        handoffToken: json['handoffToken']! as String,
      );
    } finally {
      await socket.close();
    }
  }

  Future<void> close() async {
    await _server?.close();
    _server = null;
  }
}

const _tokenA = 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';
const _tokenB = 'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB';
