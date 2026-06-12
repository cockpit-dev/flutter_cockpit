# Changelog

## 1.0.0

- Initial public release of the in-app runtime layer for `flutter_cockpit`
- Added low-intrusion root bootstrap and Flutter-native target discovery
- Added in-app control, gesture, wait/assert, capture, and recording primitives
- Added native acceptance capture and recording across Android, iOS, macOS, Windows, and Linux, with capability-truthful web rejection
- Added rich runtime snapshots, network observation, and runtime event observation
- Added remote session server, a WebSocket bridge client for web, and shared bundle/domain models
- Added sortable, readable artifact naming helpers for screenshots, diagnostics, and task-run bundles
- Guarded Android window PixelCopy capture behind API 26 so older devices report `captureUnavailable` instead of crashing
