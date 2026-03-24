---
name: flutter-cockpit
description: Use when a task needs live Flutter runtime verification, iterative hot-reload debugging, or bundle-backed acceptance evidence instead of code-only reasoning.
---

# Flutter Cockpit

## Overview

`flutter_cockpit` is for live Flutter verification. Use it when source inspection is not enough and the task needs session-backed evidence.

The key discipline is comparison, not just capture: AI should understand the final app state by comparing baseline evidence, acceptance evidence, and acceptance deltas instead of trusting command success or media readability alone.

## When to Use

Use this skill when the task involves:

- running a Flutter app
- reproducing or validating UI behavior
- checking a live route or visible state
- iterating on UI or interaction changes through edit -> reload -> probe -> diff
- generating acceptance screenshots or recordings
- reporting bundle-backed evidence to a user or another agent
- delivering validated screenshot, keyframe, or recording artifacts through a host tool that supports file attachments

Do not skip this skill for "simple" runtime tasks. Simple tasks still fail when the agent skips baseline, probe comparison, or bundle review.

### When Not to Use

Do not use this skill as the primary workflow for:

- purely static code cleanup with no runtime claim
- docs-only edits
- low-level library changes where unit tests fully answer the user request and no UI/runtime behavior is being claimed

If a task ends with "the app works now", "the UI is fixed", or "it is ready for review", this skill applies.

## Required Workflow

Follow this order every time:

1. `assess`
   Decide whether the task needs live app verification. If it does, use `flutter_cockpit`.
2. `bootstrap`
   Launch or reuse a remote session, then verify reachability before control.
   For iterative feature work, prefer a long-lived development session instead of repeatedly relaunching the app. Use:
   - `launch_development_session`
   - `reload_development_session`
   - `collect_development_probe`
   - `compare_development_probe`
   When the app follows the recommended low-friction integration pattern, target `cockpit/main.dart` for AI-driven development and leave the app's existing production entrypoint untouched. Do not assume the production target is a specific file name.
   When you inspect or patch app-side integration, prefer a single `FlutterCockpitApp(config: ..., child: MyApp())` bootstrap path. Treat direct `FlutterCockpitRoot` composition as an advanced escape hatch, not the default recommendation.
   When the app is not integrated yet, start from `examples/flutter-app-setup.md` instead of inventing a one-off bootstrap pattern.
3. `baseline`
   Capture session status and current route or app state. For verification or acceptance work, require a baseline screenshot and decide whether video evidence matters.
4. `execute`
   Prefer the development-session loop for iterative edits. Prefer the high-level `run_task` workflow only when the task is ready for heavier orchestration or acceptance evidence.
   For host-launched remote sessions, you may omit explicit script environment if remote health already exposes a real `CockpitEnvironment`. If health does not expose environment, treat that as a workflow gap to resolve explicitly, not as a license to guess.
   Prefer locator-based control first, but do not get stuck on it. When discovery is insufficient, use coordinate-aware gestures (`x`/`y`, `startX`/`startY`) as a bounded fallback instead of inventing app-specific wrappers.
   When a flow depends on shortcuts, explicit submit keys, or desktop-style interactions, use the keyboard commands instead of faking them with taps:
   - `sendKeyEvent`
   - `sendKeyDownEvent`
   - `sendKeyUpEvent`
   - `waitForUiIdle`
   When a widget exposes its most stable surface through semantics instead of pointer hit testing, prefer the semantics actions:
   - `showOnScreen`
   - `increase`
   - `decrease`
   - `dismiss`
   Keep snapshot usage proportional to need:
   - use development probes instead of full task bundles during active edit/reload cycles
   - use `live` for health and high-frequency waits
   - use `baseline` for explicit baseline or acceptance-state collection
   - use `investigate` after assertion failures, locator ambiguity, suspicious UI state, filtered network debugging, runtime-error triage, or accessibility-order debugging; when the workflow needs targeted network or runtime evidence without running a full task, call `collect_remote_snapshot`
   - use `forensic` only when lighter profiles still do not explain the issue; large remote forensic snapshots may arrive through diagnostics artifacts, so do not avoid them just because inline payloads would be large
   Interactive and diagnostic development probes may now include a fresh screenshot plus bounded `visualSignals`. Use those when you suspect spacing, color, alignment, iconography, or layout regressions that would not show up in text or semantic deltas alone.
   Rebuild summaries only appear when the app explicitly enabled diagnostics through `CockpitDiagnosticsConfig(enableRebuildTracking: true)`. Tap landing feedback is also debug-only and should never be required for acceptance claims.
   Before the final acceptance screenshot or any AI-side UI comparison that depends on a freshly loaded screen, prefer `waitForUiIdle` when the state may still be settling. `waitForNetworkIdle` is narrower; `waitForUiIdle` is the stronger gate when both rendering and API-driven state may still be moving.
   For direct runtime triage, prefer `collect_remote_snapshot` with explicit runtime filters instead of guessing from screenshots:
   - `include_runtime_activity`
   - `runtime_query.only_errors`
   - `runtime_query.message_contains`
5. `observe`
   During iterative development, compare the latest probe against the previous checkpoint before escalating to full acceptance work.
   When the latest compare result says the route/text/semantics are unchanged, still inspect `visualChanged`, `screenshotChanged`, and any added or removed `visualSignals` before concluding that hot reload did nothing.
   If probe comparison still shows no meaningful change after an edit you expected to be visible, prefer `hot_restart` or a targeted higher-profile probe before rerunning the full acceptance workflow.
   Read the resulting `manifest`, `handoff`, and `delivery`. Read `acceptance.md` when needed.
   Prefer the bundle summary `evidence` view first: it lifts primary screenshot, primary recording, extracted keyframes, diagnostics artifact paths, and delivery readiness into one bounded object.
   For acceptance-facing work, read `baseline_evidence` when it is present. It is the bounded before-state view that lets later AI compare what changed instead of reasoning from the final screen in isolation.
   For acceptance-facing work, also read `acceptance_evidence`. It is the bounded final-state view of the acceptance snapshot: route, diagnostic level, diagnostics artifact path, visible text previews, semantic IDs, interactive labels, accessibility labels with fallback signals, and compact final-state summaries for network failures, runtime errors, and rebuild hotspots.
   When the bundle summary exposes `acceptance_delta`, treat it as the first-pass comparison view. It highlights route changes, added and removed visible text, semantic IDs, interactive labels, accessibility labels, plus new network failures, runtime errors, and rebuild hotspots between baseline and acceptance.
   If the bundle summary exposes `network_summary` or `runtime_summary`, use them before guessing from screenshots alone.
   If the bundle summary exposes `diagnosticsArtifactPaths`, read those artifacts before claiming the evidence is insufficient.
   Do not pretend `validate_task` has already understood the UI. It proves the delivery bundle and AI-facing comparison dossier are present and coherent enough for review, but you still compare `baseline_evidence`, `acceptance_evidence`, `acceptance_delta`, screenshots, recordings, and any linked diagnostics artifacts to the requested outcome.
6. `judge`
   Classify the result as `completed`, `failed_with_evidence`, `blocked_by_environment`, or `needs_more_work`.
7. `deliver`
   Report status, evidence paths, and the next action when incomplete or failed.

When the task is at the final completion gate, prefer `validate_task` over raw `run_task`. `run_task` proves orchestration; `validate_task` proves the persisted bundle is delivery-ready and that the AI-facing acceptance comparison package exists when final screenshot evidence is being delivered.

## Host Delivery Boundary

When the surrounding host can send files to the user, treat validated bundle artifacts as first-class deliverables. After you have read the bundle summary and confirmed the relevant evidence paths, prefer attaching the primary screenshot, keyframes, or recording through the host tool instead of only pasting file paths in prose.

This applies to hosts such as OpenClaw or any other environment that supports outbound artifact delivery. The boundary is strict:

- `flutter_cockpit` produces and validates artifacts
- the host tool may forward those artifacts to the user
- if the host cannot send files, fall back to explicit artifact paths and say so plainly
- do not imply that `flutter_cockpit` itself sends chat messages

## Quick Reference

| Situation | Preferred tools | Minimum evidence to read |
| --- | --- | --- |
| Active edit/debug loop | `launch_development_session` -> `reload_development_session` -> `collect_development_probe` -> `compare_development_probe` | latest probe, diff summary, screenshot/visual signals when present |
| Focused runtime triage | `collect_remote_snapshot` | network/runtime summaries, diagnostics artifact paths if exposed |
| Final acceptance claim | `run_task` -> `validate_task` | `baseline_evidence`, `acceptance_evidence`, `acceptance_delta`, delivery evidence view |
| User-facing artifact handoff | validated bundle + host attachment/send capability | primary screenshot path, keyframe paths when useful, primary recording path when useful |
| Environment instability | `query_development_session` or `query_remote_session` | status, last error, missing evidence path, next action |

## Completion Gate

Do not report completion unless you have:

- verified session reachability
- executed the structured workflow
- executed the final validation gate for completion-facing work
- produced a task-run bundle
- read the summary outputs
- identified at least one evidence path
- confirmed screenshot evidence for acceptance-facing work
- read the semantic acceptance evidence for acceptance-facing work when it is present or required
- compared baseline and acceptance evidence for acceptance-facing work when both are present, using `acceptance_delta` as the bounded first-pass summary
- confirmed recording evidence when the task explicitly requires video, or explained why it is unavailable
- based the final status on post-run bundle evidence, not on command success or an earlier health query
- when the host supports file delivery and the task is user-facing, identified which validated artifacts should be attached directly instead of only quoted as paths

## Red Flags

Stop and correct your workflow if you catch yourself thinking:

- "This task is simple, so I can skip baseline."
- "The commands passed, so the state is probably correct."
- "I changed code, so I should rerun the whole acceptance workflow instead of using reload + probe + diff."
- "The probe says the text did not change, so the UI probably did not change either."
- "The UI updated, so the API probably succeeded even though I did not inspect network evidence."
- "I already checked health earlier, so I do not need to read the post-run summaries."
- "The bundle exists, so I do not need to read it."
- "Every snapshot should be forensic so I do not miss anything."
- "run_task returned completed, so I do not need validate_task."
- "One screenshot is probably enough for acceptance."
- "Video is missing, but I can still call the task done even though video was explicitly requested."
- "Recording failed, but I can still call it done without explaining the gap."
- "The error message alone is enough for handoff."
- "The acceptance screenshot looks fine, so I do not need to compare it against baseline evidence."
- "acceptance_delta is optional metadata, so I can ignore it and trust my first impression."

## Status Reference

- Session unreachable after bootstrap: `blocked_by_environment`
- Wrong app behavior with supporting evidence: `failed_with_evidence`
- Workflow ran but required acceptance evidence is missing: `needs_more_work`
- Only use `completed` when the completion gate is satisfied

## Common Mistakes

- Reading only `acceptance_evidence`: read `baseline_evidence` and `acceptance_delta` too when they exist, otherwise AI loses the before/after comparison it needs for confident judgment.
- Treating `validate_task` as semantic understanding: `validate_task` is the delivery gate, not the UI reviewer.
- Treating screenshots as self-explanatory: always use the bounded summaries first, then open diagnostics artifacts when the summaries show ambiguity.
- Treating unchanged text as unchanged UI: compare `visualSignals` and screenshot digests before concluding an edit had no effect.
- Reporting success from orchestration output: use post-run bundle evidence, not command completion, as the source of truth.
- Assuming artifact delivery is automatic: `flutter_cockpit` writes artifacts; the surrounding host must explicitly attach or send them if the user should receive the files in-chat.

## Examples

- `examples/flutter-app-setup.md`
- `examples/host-devtools-setup.md`
- `examples/runtime-validation.md`
- `examples/acceptance-delivery.md`
- `examples/failure-with-evidence.md`
