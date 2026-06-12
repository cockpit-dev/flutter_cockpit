# Task-Run Bundle Contract

Each completed `flutter_cockpit` task writes a single task-run bundle directory. The directory name is derived from the session start timestamp and session ID using a file-system-safe timestamp format.

This contract is the stable handoff boundary between app instrumentation, host-side devtools, later AI agents, and external acceptance delivery. New fields can be added, but the bundle must remain readable as a portable directory of JSON, markdown, and binary evidence files.

Remote session bootstrap metadata is intentionally outside this contract. A host-side launcher may emit a separate session-handle JSON file before any task-run exists; later CLI commands can reuse that handle to reach the running app and produce a bundle that follows the contract below.

`issue_evidence.json` is the first troubleshooting entry point for failed or degraded bundles. It is intentionally compact and reconstructible from the standard bundle files. Later AI agents should read it before opening full step logs, screenshots, recordings, or large diagnostics snapshots.

## AI-Facing Summary Layer

The bundle directory is the durable source of truth. Later tooling may expose a bounded summary view derived from the bundle, but that summary is a consumer surface, not a second persistence format.

The current repository exposes this through CLI `read-task-bundle-summary` and MCP `read_task_bundle_summary`, which may derive:

- `evidence`
- `evidenceSummary`
- `gateSummary`
- `issueEvidence`
- `baselineEvidence`
- `acceptanceEvidence`
- `acceptanceDelta`

The bounded summary layer may add plane-aware fields such as:

- `targetKind`
- `primaryExecutionPlane`
- `planesUsed`
- `surfaceKindsUsed`
- `fallbackCount`
- `targetReachable`
- `intendedPlaneWorked`
- `fallbackAcceptable`
- `postconditionsSatisfied`
- `artifactsReady`
- `logsCollected`
- `deliveryReadable`

These derived objects must remain traceable back to files in the bundle, especially `manifest.json`, `handoff.json`, `delivery.json`, `acceptance.md`, `steps.json`, `observations.json`, and any referenced artifacts under `screenshots/`, `recordings/`, `keyframes/`, or `diagnostics/`.
Summary field names follow the same lower camel case convention as the rest of the public CLI and MCP JSON surfaces.
The bounded summary layer may also expose additive gate-oriented views such as delivery readiness or acceptance-evidence readability, but those views must remain reconstructible from persisted bundle files rather than ephemeral in-memory orchestration state.

This contract therefore covers both:

- the persisted bundle layout itself
- the requirement that later AI tooling can reconstruct a bounded before/after comparison view from that layout without inventing extra off-bundle state

## Required Layout

Every bundle directory must contain:

- `manifest.json`
- `environment.json`
- `steps.json`
- `observations.json`
- `logs.json`
- `acceptance.md`
- `handoff.json`
- `delivery.json`
- `issue_evidence.json`
- `screenshots/`
- `recordings/`
- `keyframes/` when recording-derived delivery frames are emitted
- `diagnostics/` when rich snapshot artifacts are emitted

## File Roles

### `manifest.json`

The manifest is the top-level summary for a task-run bundle. It must include:

- `sessionId`
- `taskId`
- `platform`
- `status`
- `startedAt`
- `finishedAt`
- `artifactRefs`
- `failureSummary` when the task ends in failure
- `targetKind`
- `primaryExecutionPlane`
- `planesUsed`
- `surfaceKindsUsed`
- `fallbackCount`
- `capabilitiesUsed`
- `commandCount`
- `screenshotCount`
- `failureCount`
- `nativeScreenshotCount`
- `flutterScreenshotCount`
- `deliveryArtifactsReady`
- `deliveryArtifactFailureCodes`
- `recordingCount`
- `nativeRecordingCount`
- `deliveryVideoReady`
- `deliveryVideoFailureCodes`
- `runtimeEventCount`
- `runtimeErrorCount`
- `runtimeWarningCount`

`artifactRefs` is the bundle-wide evidence index. Command steps can still keep their own `artifactRefs` and `captureRefs`, but the manifest is the top-level place to discover every referenced artifact.

### `environment.json`

The environment snapshot captures the runtime context that the AI used while executing the task. The current implementation records:

- `platform`
- `flutterVersion`
- `dartVersion`

Future phases may add more environment metadata, but these keys remain the current minimum contract.

### `steps.json`

The steps file records every action emitted by `CockpitSessionController`. Each step includes:

- step `index`
- `actionType`
- `actionArgs`
- `observedAt`
- optional `observation`
- optional `snapshot`
- optional `artifactRefs`
- optional `commandType`
- optional `locator`
- optional `locatorResolution`
- optional `commandError`
- optional `durationMs`
- optional `status`
- optional `targetKind`
- optional `executionPlane`
- optional `surfaceKind`
- optional `fallbackTrail`
- optional `usedPlaneFallback`
- optional `requestedCaptureProfile`
- optional `resolvedCaptureKind`
- optional `usedCaptureFallback`
- optional `degradationReason`
- optional `captureRefs`

Control and capture flows should record structured command metadata instead of flattening everything into free-form logs. `captureRefs` is reserved for screenshot evidence associated with that step. AI-default command execution adds best-effort `after_action` screenshots for key mutating operations; these captures use `captureFailurePolicy: degradeCommand` so the original successful action can still be recorded with `usedCaptureFallback` and `degradationReason` if evidence capture fails.
Failed command steps should preserve `commandError`, including `details.failureDiagnostics` when available, so a later bundle reader can distinguish locator failures, activation failures, route failures, UI-stability failures, runtime errors, and environment failures without guessing.
When a step snapshot reaches `forensic` detail or needs truncation, the inline `snapshot` in `steps.json` should stay summarized and point to a full `diagnostics/*.json` payload through `diagnosticsArtifactRef`.

### `observations.json`

The observations file stores the extracted observation list for the bundle. Each observation currently includes:

- optional `routeName`
- `interactiveElements`
- optional `phase`
- optional `diagnosticLevel`
- optional `truncated`
- optional `diagnosticsArtifactRef`
- optional `summary`
- optional `targetKind`
- optional `executionPlane`
- optional `surfaceKind`
- optional `fallbackUsed`

`phase` marks when the observation was collected in the execution flow. Current values are:

- `baseline`
- `beforeAction`
- `afterAction`
- `failure`

### `logs.json`

The logs file is the dedicated, chronologically ordered log evidence for the task run. It is derived from the recorded steps so it never invents off-bundle state. It must include:

- `sessionId`
- `taskId`
- `platform`
- `runtimeEventCount`
- `runtimeErrorCount`
- `runtimeWarningCount`
- `entryCount`
- `entries`

Each entry carries a `source` of `runtime` (runtime events, Flutter errors, uncaught errors, debug logs) or `network` (observed HTTP activity) plus the original payload fields. Entries are deduplicated by event/request id and sorted by recorded time. The file is written even when no log evidence exists so consumers can rely on its presence.

### `acceptance.md`

Human-readable summary intended for review and downstream delivery. It must describe the session, task, platform, final status, and step count. Failure bundles must include the failure summary.
When a recording is generated, the acceptance summary must also describe whether user-facing video evidence is ready and which bundle path contains the primary recording.
When recording-derived keyframes are available, the acceptance summary should also summarize keyframe count and whether timeline coverage is considered ready.

### `handoff.json`

Machine-readable summary intended for the next automation step. The current implementation includes:

- `sessionId`
- `taskId`
- `platform`
- `status`
- optional `targetKind`
- optional `primaryExecutionPlane`
- optional `planesUsed`
- optional `surfaceKindsUsed`
- `fallbackCount`
- `stepCount`
- `capabilitiesUsed`
- `commandCount`
- `screenshotCount`
- `failureCount`
- optional `failureSummary`
- `nativeScreenshotCount`
- `flutterScreenshotCount`
- `deliveryArtifactsReady`
- `deliveryArtifactFailureCodes`
- `recordingCount`
- `nativeRecordingCount`
- `deliveryVideoReady`
- `deliveryVideoFailureCodes`
- `screenshotReady`
- `recordingReadyOrExplained`
- `deliveryValidated`
- `gates`
- `gateFailureCodes`

This file is intentionally compact. It should give a later tool or AI agent enough execution context to decide what to do next without re-parsing every step immediately.
`gates` and `gateFailureCodes` are additive readiness hints. They do not replace full validation, but they let downstream AI quickly see which screenshot, recording, or delivery gate failed and which bounded failure codes explain that state.
Current plane-aware gates may include:

- `targetReachable`
- `intendedPlaneWorked`
- `fallbackAcceptable`
- `postconditionsSatisfied`
- `artifactsReady`
- `logsCollected`
- `deliveryReadable`
- `screenshotReady`
- `recordingReadyOrExplained`
- `deliveryValidated`

### `delivery.json`

Machine-readable delivery summary intended for later sender integrations. The current implementation includes:

- `summary`
- `primaryScreenshotRef`
- `attachmentRefs`
- `deliveryArtifactsReady`
- `artifactFailureCodes`
- `primaryRecordingRef`
- `videoAttachmentRefs`
- `deliveryVideoReady`
- `videoFailureCodes`
- `readiness`
- `keyframes`
- `keyframeCoverage`
- `deliveryKeyframesReady`
- optional `keyframeFailureReason`

`delivery.json` must only reference files that already exist inside the bundle. It is a handoff layer for delivery tooling, not a second artifact store.
Each `keyframes` entry must include a bundle-relative `ref`, a semantic `label`, an `offsetMs`, and the extraction `source`.
The optional `readiness` object should explain screenshot and video delivery state using bounded booleans and failure codes so a later AI agent can distinguish “ready”, “missing”, and “degraded but understood” states without reopening the full step log.

### `issue_evidence.json`

Machine-readable troubleshooting packet intended for AI-first recovery. The current implementation includes:

- `schemaVersion`
- `bundleDir`
- `sessionId`
- `taskId`
- `platform`
- `status`
- optional `failureSummary`
- `recommendedNextStep`
- `issueKinds`
- `counts`
- `failedCommands`
- `runtimeIssues`
- `networkIssues`
- `artifactIssues`
- `gateFailures`
- `evidencePaths`

`failedCommands` must include the command ID, type, route, expected route, locator, error code, error message, `failureDiagnostics` when present, and any diagnostics artifact path that can explain the failure. `runtimeIssues` and `networkIssues` are bounded previews, not full logs. `artifactIssues` must report missing or unreadable evidence files, including diagnostics artifacts, without making the whole summary unreadable. `evidencePaths` points to the smallest useful persisted artifacts so AI can defer opening large files until the compact packet no longer explains the next repair.

## Artifact Placement Rules

- Screenshot files belong in `screenshots/`
- Recording files belong in `recordings/`
- Recording-derived keyframes belong in `keyframes/`
- Rich diagnostic snapshot files belong in `diagnostics/`
- Framework-generated bundle directories and screenshot artifact names must start with a fixed-width UTC token formatted as `YYYYMMDDTHHMMSSffffffZ`, for example `20260530T060304005006Z`. This keeps filenames readable, portable, and lexically sortable by time.
- Framework-generated recording keyframe names must start with an eight-digit recording offset token such as `00004800ms_`. This keeps `keyframes/` directory listings in timeline order while preserving the semantic label after the offset.
- User-supplied recording artifact names may remain semantic-name-first because those files are usually final delivery media; chronological ordering is already supplied by the enclosing task-run bundle directory.
- `artifactRefs.relativePath` values must point to files under those directories using bundle-relative paths
- Bundle writers must create `screenshots/` and `recordings/` even when they are empty so downstream tooling can rely on a stable layout
- When binary artifact payloads are available, writers should persist them at the referenced relative paths inside the bundle directory
- When artifacts are produced as native temp files instead of in-memory bytes, bundle writers should copy those source files into the referenced bundle-relative paths
- When artifacts are produced by a remote app session, host-side tooling may first need to transfer them over the remote session before persisting them into the referenced bundle-relative paths
- When snapshots are externalized for diagnostics, bundle writers must persist the full JSON payload at the referenced `diagnostics/*.json` path and keep the inline bundle snapshot summarized rather than duplicating the heaviest fields everywhere
- When a primary recording exists, bundle writers should extract multiple PNG keyframes into `keyframes/` and record their offsets and coverage metadata in `delivery.json` so downstream acceptance flows do not rely on a single end frame

The current `TaskRunBundleWriter` supports both writing referenced binary payloads and copying referenced source files alongside the JSON bundle files. This is how screenshot bytes and native recording files move from an in-app capture result into a durable task-run bundle.
The same artifact rules apply to host-side remote runs: when the running app returns inline remote artifact payloads, host-side tooling must persist them to the referenced bundle-relative paths instead of keeping them only in command metadata. When a remote recording returns a downloadable artifact descriptor, host-side tooling must fetch that artifact and write it into the bundle before considering `deliveryVideoReady` satisfied.
When host-side recording fallback is used, the recording artifact may already exist on the host filesystem. In that case the bundle writer must still copy the source file into `recordings/` before considering `deliveryVideoReady` satisfied.
Final delivery validation must treat these artifact files as real media, not opaque blobs. Host-side validation should prefer `ffprobe` when available, and otherwise fall back to built-in PNG and MP4 structural checks before a task is considered delivery-ready.
For recorded runs, delivery validation should also reject bundles where extracted keyframes are missing or do not cover the beginning, midpoint, and end of the acceptance timeline.

## Compatibility Rules

- The bundle format must remain JSON-based and file-system portable
- Timestamp-based directory naming must avoid characters that are invalid on common filesystems
- Required files and required top-level manifest keys must not be removed without a versioned migration plan
- New optional fields may be added as long as older consumers can safely ignore them
