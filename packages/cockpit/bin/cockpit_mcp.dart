import 'package:cockpit/cockpit.dart';

Future<void> main() async {
  await CockpitMcpServer.standard().serveStdio();
}
