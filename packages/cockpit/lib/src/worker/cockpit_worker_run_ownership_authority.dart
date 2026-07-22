abstract interface class CockpitWorkerRunOwnershipAuthority {
  Future<Set<String>> findOwnedRunIds({
    required String workspaceId,
    required Set<String> candidateRunIds,
  });
}

final class CockpitDenyAllWorkerRunOwnershipAuthority
    implements CockpitWorkerRunOwnershipAuthority {
  const CockpitDenyAllWorkerRunOwnershipAuthority();

  @override
  Future<Set<String>> findOwnedRunIds({
    required String workspaceId,
    required Set<String> candidateRunIds,
  }) async => const <String>{};
}
