import 'package:flutter_cockpit_protocol/flutter_cockpit_protocol.dart';

CockpitRecordingRequest cockpitDefaultDevelopmentRecordingRequest({
  DateTime? now,
}) {
  final timestamp = cockpitSortableTimestampToken(now ?? DateTime.now());
  return CockpitRecordingRequest(
    purpose: CockpitRecordingPurpose.repro,
    name: '${timestamp}_development-recording',
  );
}
