# Task-Run Bundle Contract

Each completed `flutter_cockpit` task writes a single task-run bundle directory. The directory name is derived from the session start timestamp and session ID using a file-system-safe timestamp format.

This contract is the stable handoff boundary between app instrumentation, host-side devtools, later AI agents, and external acceptance delivery. New fields can be added, but the bundle must remain readable as a portable directory of JSON, markdown, and binary evidence files.

Remote session bootstrap metadata is intentionally outside this contract. A host-side launcher may emit a separate session-handle JSON file before any task-run exists; later CLI commands can reuse that handle to reach the running app and produce a bundle that follows the contract below.

## AI-Facing Summary Layer

The bundle directory is the durable source of truth. Later tooling may expose a bounded summary view derived from the bundle, but that summary is a consumer surface, not a second persistence format.

The current repository exposes this through `read_task_bundle_summary`, which may derive:

- `evidence`
- `baseline_evidence`
- `acceptance_evidence`
- `acceptance_delta`

These derived objects must remain traceable back to files in the bundle, especially `manifest.json`, `handoff.json`, `delivery.json`, `acceptance.md`, `steps.json`, `observations.json`, and any referenced artifacts under `screenshots/`, `recordings/`, `keyframes/`, or `diagnostics/`.

This contract therefore covers both:

- the persisted bundle layout itself
- the requirement that later AI tooling can reconstruct a bounded before/after comparison view from that layout without inventing extra off-bundle state

## Required Layout

Every bundle directory must contain:

- `manifest.json`
- `environment.json`
- `steps.json`
- `observations.json`
- `acceptance.md`
- `handoff.json`
- `delivery.json`
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
- `capabilitiesUsed`
- `commandCount`
- `screenshotCount`
- `failureCount`
- `nativeScreenshotCount`
- `flutterScreenshotCount`
- `deliveryArtifactsReady`
- `recordingCount`
- `nativeRecordingCount`
- `deliveryVideoReady`

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
- optional `durationMs`
- optional `status`
- optional `requestedCaptureProfile`
- optional `resolvedCaptureKind`
- optional `usedCaptureFallback`
- optional `degradationReason`
- optional `captureRefs`

Control and capture flows should record structured command metadata instead of flattening everything into free-form logs. `captureRefs` is reserved for screenshot evidence associated with that step.
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

`phase` marks when the observation was collected in the execution flow. Current values are:

- `baseline`
- `beforeAction`
- `afterAction`
- `failure`

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
- `stepCount`
- `capabilitiesUsed`
- `commandCount`
- `screenshotCount`
- `failureCount`
- optional `failureSummary`
- `nativeScreenshotCount`
- `flutterScreenshotCount`
- `deliveryArtifactsReady`
- `recordingCount`
- `nativeRecordingCount`
- `deliveryVideoReady`

This file is intentionally compact. It should give a later tool or AI agent enough execution context to decide what to do next without re-parsing every step immediately.

### `delivery.json`

Machine-readable delivery summary intended for later sender integrations. The current implementation includes:

- `summary`
- `primaryScreenshotRef`
- `attachmentRefs`
- `deliveryArtifactsReady`
- `primaryRecordingRef`
- `videoAttachmentRefs`
- `deliveryVideoReady`
- `keyframes`
- `keyframeCoverage`
- `deliveryKeyframesReady`
- optional `keyframeFailureReason`

`delivery.json` must only reference files that already exist inside the bundle. It is a handoff layer for delivery tooling, not a second artifact store.
Each `keyframes` entry must include a bundle-relative `ref`, a semantic `label`, an `offsetMs`, and the extraction `source`.

## Artifact Placement Rules

- Screenshot files belong in `screenshots/`
- Recording files belong in `recordings/`
- Recording-derived keyframes belong in `keyframes/`
- Rich diagnostic snapshot files belong in `diagnostics/`
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
