# Changelog

## 1.0.0

- Initial public release of the in-app runtime layer for `flutter_cockpit`
- Added low-intrusion root bootstrap and Flutter-native target discovery
- Added in-app control, gesture, wait/assert, capture, and recording primitives
- Added native acceptance capture and recording across Android, iOS, macOS, Windows, and Linux, with capability-truthful web rejection
- Added rich runtime snapshots, network observation, and runtime event observation
- Added remote session server, a WebSocket bridge client for web, and shared bundle/domain models
- Added sortable, readable artifact naming helpers for screenshots, diagnostics, and task-run bundles
- Added `waitFor` absent mode (`parameters.absent: true`) so flows can wait for spinners, dialogs, or routes to disappear
- Added direct activation for Radio/RadioListTile and the real tristate Checkbox cycle, with occlusion-safe multi-touch validation and pointer-cancel cleanup
- Added release-build semantics resolution through the live SemanticsOwner tree so the semantic plane stays truthful outside debug builds
- Defaulted `CockpitInteractionPolicy.hitTestMissPolicy` to `fail` so taps that miss their target surface as errors instead of silently passing as no-ops
- Guarded Android window PixelCopy capture behind API 26 so older devices report `captureUnavailable` instead of crashing
