import 'package:flutter_cockpit_devtools/flutter_cockpit_devtools.dart';

Future<void> main() async {
  await CockpitMcpServer.standard().serveStdio();
}
