import 'dart:io';

import 'cockpit_remote_bridge_protocol.dart';

CockpitRemoteBridgeBinaryFileReader
cockpitCreateRemoteBridgeBinaryFileReader() {
  return (sourceFilePath) => File(sourceFilePath).readAsBytes();
}
