# cockpit_protocol

Platform-neutral Dart protocol models shared by Cockpit clients, runtimes,
drivers, and host tooling.

Most users should depend on `flutter_cockpit` in Flutter apps and `cockpit` for
host tooling. Direct protocol consumers import
`package:cockpit_protocol/cockpit_protocol.dart`. This package has no Flutter SDK
dependency, so CLI, MCP, GUI, and third-party clients can share the same wire
models.

Version 2.0 replaces the former `flutter_cockpit_protocol` package. There is no
compatibility forwarding package.
