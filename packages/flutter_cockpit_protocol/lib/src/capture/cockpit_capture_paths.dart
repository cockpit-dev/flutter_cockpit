// ignore_for_file: deprecated_member_use

import '../control/cockpit_screenshot_request.dart';
import '../model/cockpit_artifact_naming.dart';

String cockpitScreenshotRelativePathFor(
  CockpitScreenshotRequest request, {
  DateTime? now,
}) {
  final timestamp = cockpitSortableTimestampToken(now ?? DateTime.now());
  final stem = cockpitSanitizeArtifactNameToken(
    request.name,
    fallback: 'capture',
    lowercase: true,
  );
  return 'screenshots/${timestamp}_${stem}_${request.reason.jsonValue}.png';
}
