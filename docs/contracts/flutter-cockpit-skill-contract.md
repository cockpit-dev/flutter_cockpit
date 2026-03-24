# Flutter Cockpit Skill Contract

## Purpose

This contract defines the maintainer-facing guarantees for the `flutter-cockpit` skill.

The skill exists to constrain AI behavior while using the repository's existing Flutter runtime verification workflow. It is not a replacement for CLI, MCP, protocol, or bundle documentation.

## Scope

The contract covers:

- the repository capabilities the skill is allowed to depend on
- the mandatory workflow stages the skill must enforce
- the completion gate an agent must satisfy before reporting success
- the failure taxonomy an agent must use when the workflow does not end in success
- the boundary between bundle generation and optional host-mediated artifact delivery

The contract does not cover:

- future skill invocation APIs
- automatic script generation
- automatic task planning
- direct in-framework chat delivery

## Current Capability Dependencies

The skill may depend on these currently implemented repository workflows:

- development-session bootstrap through `launch-development-session`
- development-session lifecycle control through `query-development-session`, `reload-development-session`, and `stop-development-session`
- bounded iterative inspection through `collect-development-probe` and `compare-development-probe`
- screenshot-backed development probes with bounded `visualSignals` and screenshot digest comparison
- remote session bootstrap through `launch-remote-session`
- remote session health reads through `query-remote-session`
- structured remote execution through `run-remote-control-script`
- high-level workflow orchestration through `run-task` / `run_task`
- final delivery validation through `validate-task` / `validate_task`
- remote-health environment resolution when the session exposes a real `CockpitEnvironment`
- task-run bundle output with:
  - `manifest.json`
  - `handoff.json`
  - `delivery.json`
  - `acceptance.md`
- AI-facing bundle summary evidence views with:
  - `baseline_evidence`
  - `acceptance_evidence`
  - `acceptance_delta`
- host-mediated delivery of validated artifact files when the surrounding tool supports attachments or outbound file transfer

Current first-class host bootstrap paths include:

- Android emulators
- iOS Simulators
- local macOS desktop runs

Current first-class recording delivery paths include:

- Android and iOS in-app native acceptance recording
- Android emulator host recording via `adb screenrecord`
- iOS Simulator host recording via `xcrun simctl io recordVideo`
- macOS host-preferred screenshot/recording with bounded fallback to remote screenshot or synthesized timeline video when host tooling cannot yield stable media on the current machine

The skill must not require capabilities that are not implemented today.

## Mandatory Workflow Stages

The skill must enforce these stages:

1. `assess`
2. `bootstrap`
3. `baseline`
4. `execute`
5. `observe`
6. `judge`
7. `deliver`

### `assess`

The agent must decide whether the task requires `flutter_cockpit`.

The skill must require `flutter_cockpit` when the task involves:

- running a Flutter app
- reproducing or verifying UI behavior
- validating a user-visible outcome
- producing acceptance evidence

### `bootstrap`

The agent must ensure the remote session is reachable before interactive control begins.

The skill must not allow:

- remote control execution against an unverified session
- skipping session health when a running app is being reused

### `baseline`

The agent must collect baseline evidence before key actions.

Minimum baseline requirements:

- session status
- current route or app state
- baseline screenshot when the task is verification- or acceptance-facing
- recording strategy awareness when the task expects video evidence

### `execute`

The agent must prefer structured workflow execution that produces bundle-backed evidence instead of ad hoc shell interactions for the main verification path.

For active edit/reload cycles, the skill must prefer the development-session workflow over repeatedly relaunching the entire app. Final `run-task` / `validate-task` should only happen when the feature or fix is ready for heavier acceptance validation.

For iterative visual work, the skill must treat screenshot-backed development probes as the primary source of truth before final acceptance. Lack of text or semantic change is not sufficient proof that the visible UI is unchanged.

When the remote session health exposes environment metadata, the agent may rely on that runtime environment instead of restating it in every control script.

When the remote session health does not expose environment metadata, the agent must not guess missing environment values.

### `observe`

The agent must inspect task-run outputs after execution.

Minimum required reads:

- `manifest`
- `handoff`
- `delivery`
- `acceptance_evidence` for acceptance-facing work when it is present or required

Optional reads when needed:

- `acceptance.md`
- concrete artifact paths referenced by the bundle

For acceptance-facing work, when bundle summary exposes `baseline_evidence` and `acceptance_delta`, the skill must require the agent to read them before making a completion claim. The contract treats them as the bounded before/after comparison layer that closes the gap between "media is readable" and "AI has actually compared the UI state."

For iterative development work, when probe diff exposes `visualChanged`, `screenshotChanged`, or `visualSignals`, the skill must require the agent to treat those as meaningful change signals even if route, text, and semantic IDs are unchanged.

For completion-facing work, the skill should prefer the dedicated validation workflow so the final claim is based on persisted bundle checks, not only orchestration output.

### `judge`

The agent must classify the result explicitly, not vaguely.

### `deliver`

The agent must produce a final report with status, evidence paths, and next-step guidance when incomplete.

When the surrounding host tool supports sending files to the user, the skill may also require the agent to attach validated screenshot, keyframe, or recording artifacts. The contract boundary is:

- `flutter_cockpit` is responsible for producing and validating artifact files
- the host tool is responsible for actually attaching or sending those files in chat or another delivery channel
- if the host tool cannot send files, the skill falls back to explicit artifact paths and status reporting
- the skill must never imply that `flutter_cockpit` itself performs chat delivery

## Completion Gate

The skill must forbid completion claims unless the agent has:

- verified session reachability
- executed the structured workflow
- used the validation workflow when making a final completion claim
- produced a task-run bundle
- read the resulting summary outputs
- identified at least one evidence path
- confirmed screenshot availability for acceptance-facing work
- read semantic acceptance evidence for acceptance-facing work when present or explicitly required by validation
- read baseline evidence and acceptance delta for acceptance-facing work when they are present
- use the bounded final-state dossier inside `acceptance_evidence` to compare final UI, network, runtime, and rebuild signals instead of relying on media readability alone
- use `acceptance_delta` as the bounded first-pass comparison between baseline and acceptance, then open linked diagnostics artifacts only when the bounded comparison is still insufficient
- confirmed recording availability when the task explicitly requires video, or explicitly described why recording is unavailable
- when the host supports artifact delivery and the task is user-facing, selected the validated screenshot, keyframe, or recording files that should be sent to the user

If any of these are missing, the result must not be classified as `completed`.

## Failure Taxonomy

The skill must require the agent to distinguish between:

- `completed`
- `failed_with_evidence`
- `blocked_by_environment`
- `needs_more_work`

### `completed`

Use only when the completion gate is fully satisfied.

### `failed_with_evidence`

Use when the app workflow or asserted outcome failed, and the agent can point to supporting bundle evidence.

### `blocked_by_environment`

Use when the environment prevented a valid run, such as:

- session unreachable after bootstrap
- environment-specific recording or connectivity failure
- execution blocked before the app behavior could be meaningfully evaluated

### `needs_more_work`

Use when the run partially succeeded but the acceptance or completion gate is incomplete, such as:

- missing required screenshot evidence
- missing required recording explanation
- bundle exists but the agent has not yet validated the outcome fully

## Red-Line Non-Goals

The skill must not:

- teach every CLI option
- act as a full MCP reference
- claim completion from command success alone
- treat bundle existence as sufficient proof of success
- rely on repository capabilities that do not exist on the current mainline
- imply that bundle generation automatically means the user has received the artifacts
