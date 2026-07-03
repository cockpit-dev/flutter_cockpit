import 'package:flutter_cockpit_protocol/flutter_cockpit_protocol.dart';

void main() {
  const entry = CockpitRebuildEntry(
    signature: 'sig',
    routeName: '/inbox',
    typeName: 'Text',
    rebuildCount: 1,
    builtOnceCount: 1,
  );

  final snapshot = CockpitRebuildSnapshot(
    totalRebuildCount: 1,
    uniqueElementCount: 1,
    capturedEntryCount: 1,
    truncated: false,
    entries: const <CockpitRebuildEntry>[entry],
  );

  final json = snapshot.toJson();
  if (json['totalRebuildCount'] != 1) {
    throw StateError('Unexpected rebuild snapshot serialization.');
  }
}
