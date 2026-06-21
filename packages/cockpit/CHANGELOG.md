# Changelog

## 1.0.0

- Initial public release of the host-side tooling layer for `flutter_cockpit`
- Added CLI and MCP entrypoints for session bootstrap, control execution, snapshot collection, orchestration, and validation
- Added the Native/System Control Plane: `read-system-capabilities` and `run-system-action` (CLI and MCP) with capability-truthful Android adb, iOS simctl+WebDriverAgent, desktop, and web profiles, declared parameter contracts, and payload validation
- Added scene-level system macros for real debugging blockers: `resolveBlockers`, `preparePermissions`, `recoverToApp`, `tapNotification`, `readFocusState`, and `stabilizeForScreenshot`
- Added Android SystemUI demo-mode status bar overrides (`setStatusBar`/`clearStatusBar`) for deterministic screenshot evidence
- Added desktop host-plane actions through built-in tooling: system settings entry, host appearance, host file push/pull and media copy, app recovery, focus and device reads, notifications, and macOS `tccutil` permission resets
- Added web (browser) evidence through host window adapters so screenshots and recordings work once the browser app id or process id is known
- Added native system log reads (`readSystemLogs`: logcat, unified log, journalctl, Windows event log) so startup crashes are diagnosable before the runtime observer attaches
- Added Android battery simulation (`setBattery`) and connectivity toggles (`setConnectivity`), plus iOS simulator locale switching (`setLocale`)
- Added task-run bundle writing, summary shaping, structured `logs.json` evidence, and delivery evidence handling
- Added `read-task-bundle-summary` CLI output for low-token bundle review alongside MCP `read_task_bundle_summary`
- Added AI-readable default stdout rendering with JSON/path/file output formats for shell-friendly workflows
- Added sortable task-run bundle names, screenshot names, and recording keyframe paths for chronological artifact review
- Added host-side screenshot and recording adapters with validation and keyframe extraction
- Added remote session launchers for Android emulators, iOS simulators and devices, macOS, Windows, and Linux, with best-effort app cleanup when launch readiness fails
- Added collapsible Devtools dashboard panels with persisted panel layout and global collapse/expand controls for dense timeline, evidence, launcher, and inspector reviews
- Fixed screenshot-only task bundle summaries so stale recording failure fields no longer block delivery gates when video was not requested
- Fixed development `launch-app` so it returns after readiness while the background supervisor keeps logs, reload, restart, and stop control alive
- Fixed `run-shell` and host recorder helper commands so short CLI/MCP calls are bounded, killable, and do not inherit recording startup timeouts
- Fixed stale development `stop-app` cleanup so platform app processes are stopped even when the supervisor is already unreachable
- Fixed the real MCP surface verifier so `serve-mcp` shutdown cleanup is bounded and cannot hang the validation run
