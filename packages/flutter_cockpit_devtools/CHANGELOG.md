# Changelog

## 1.0.0

- Initial public release of the host-side tooling layer for `flutter_cockpit`
- Added CLI and MCP entrypoints for session bootstrap, control execution, snapshot collection, orchestration, and validation
- Added task-run bundle writing, summary shaping, and delivery evidence handling
- Added `read-task-bundle-summary` CLI output for low-token bundle review alongside MCP `read_task_bundle_summary`
- Added AI-readable default stdout rendering with JSON/path/file output formats for shell-friendly workflows
- Added sortable task-run bundle names, screenshot names, and recording keyframe paths for chronological artifact review
- Added host-side screenshot and recording adapters with validation and keyframe extraction
- Added remote session launchers for Android emulators and iOS Simulators
- Fixed development `launch-app` so it returns after readiness while the background supervisor keeps logs, reload, restart, and stop control alive
- Fixed `run-shell` and host recorder helper commands so short CLI/MCP calls are bounded, killable, and do not inherit recording startup timeouts
- Fixed stale development `stop-app` cleanup so platform app processes are stopped even when the supervisor is already unreachable
- Fixed the real MCP surface verifier so `serve-mcp` shutdown cleanup is bounded and cannot hang the validation run
