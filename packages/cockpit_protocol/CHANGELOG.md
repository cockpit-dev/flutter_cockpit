# Changelog

## 2.0.0

- Renamed the pure-Dart package from `flutter_cockpit_protocol` to
  `cockpit_protocol` as the sole owner of platform-neutral Cockpit models.
- Renamed the public libraries to `cockpit_protocol.dart` and
  `cockpit_remote_bridge_protocol.dart` without a compatibility forwarding
  package.

## 1.1.4

- Synced the published protocol contract fallback documents with the repository contracts so global tooling and MCP resources expose the same AI development and bundle traceability protocol as monorepo checkouts.

## 1.1.3

- Initial pure Dart protocol package extracted from `flutter_cockpit` so `cockpit` can run as a hosted global Dart executable.
