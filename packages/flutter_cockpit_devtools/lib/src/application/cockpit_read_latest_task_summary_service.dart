import 'cockpit_latest_task_store.dart';

final class CockpitReadLatestTaskSummaryService {
  const CockpitReadLatestTaskSummaryService({
    required CockpitLatestTaskStore store,
  }) : _store = store;

  final CockpitLatestTaskStore _store;

  CockpitLatestTaskSnapshot? read() => _store.latest;
}
