// ignore_for_file: deprecated_member_use

import 'cockpit_recording_request.dart';

String cockpitRecordingRelativePathFor(CockpitRecordingRequest request) {
  final sanitizedName = request.name.replaceAll(
    RegExp(r'[^A-Za-z0-9._-]'),
    '_',
  );
  return 'recordings/$sanitizedName.mp4';
}
