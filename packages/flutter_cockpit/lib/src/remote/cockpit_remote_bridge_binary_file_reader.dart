import 'cockpit_remote_bridge_binary_file_reader_stub.dart'
    if (dart.library.io) 'cockpit_remote_bridge_binary_file_reader_io.dart';
import 'cockpit_remote_bridge_protocol.dart';

CockpitRemoteBridgeBinaryFileReader? cockpitRemoteBridgeBinaryFileReader() {
  return cockpitCreateRemoteBridgeBinaryFileReader();
}
