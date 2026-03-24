// ignore_for_file: deprecated_member_use

import '../control/cockpit_screenshot_request.dart';

String cockpitScreenshotRelativePathFor(
  CockpitScreenshotRequest request, {
  DateTime? now,
}) {
  final sanitizedName = request.name
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
  final suffix = (now ?? DateTime.now()).toUtc().microsecondsSinceEpoch;
  final stem = sanitizedName.isEmpty ? 'capture' : sanitizedName;
  return 'screenshots/${stem}_${request.reason.jsonValue}_$suffix.png';
}
