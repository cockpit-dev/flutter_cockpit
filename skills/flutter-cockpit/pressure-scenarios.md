# Flutter Cockpit Pressure Scenarios

## Overview

This document is the RED/GREEN/REFACTOR test basis for the `flutter-cockpit` skill.

- `RED`: record what an agent does without the skill
- `GREEN`: write the smallest skill that fixes the observed failures
- `REFACTOR`: rerun the same scenarios, capture new loopholes, and tighten the skill

The goal is not to imagine failures. It is to record the workflow shortcuts an unassisted agent is most likely to take when using `flutter_cockpit` for production-facing Flutter work.

## Scenario Format

Each scenario contains:

- a pressure prompt
- the naive failure expected before the skill exists
- a concrete baseline observation
- the corrected behavior expected after the skill is loaded

## Scoring Rubric

Each scenario is evaluated against six checks:

1. Did the agent verify session reachability before executing app actions?
2. Did the agent collect or reference baseline evidence before key actions?
3. Did the agent read bundle summary outputs before judging success or failure?
4. Did the agent report concrete artifact paths and a clear final status?
5. Did the agent compare baseline and acceptance evidence when both were available?
6. Did the agent clearly separate “bundle produced artifacts” from “host delivered artifacts to the user”?

If any answer is `no`, the workflow is not production-grade.

## Scenario 1: Acceptance Pressure

### Prompt

You changed a Flutter UI flow. Validate it end to end, produce user-facing acceptance evidence, and report back whether it is ready for review.

### Expected Naive Failure

The agent treats "acceptance" as "run something and attach one screenshot," skips an explicit validation step, and reports success without checking whether the bundle contains the expected screenshot and recording artifacts.

### Baseline Observation

Baseline dry-run observation on 2026-03-21:

- the agent moved quickly from "task sounds like acceptance" to "run the interaction"
- it treated the existence of generated output as sufficient proof, rather than checking `manifest`, `handoff`, and `delivery`
- its implicit shortcut was: "if the run completed and a screenshot exists somewhere, that is probably enough for acceptance"
- the missing behavior was an explicit artifact-backed completion decision

### Target Corrected Behavior

The agent must:

- confirm the task is acceptance-facing
- require screenshot evidence and recording status
- read `manifest`, `handoff`, and `delivery`
- report concrete artifact paths before calling the task complete

### Post-Skill Validation

Validation rerun on 2026-03-21 with `skills/flutter-cockpit/SKILL.md` present:

- the workflow now forces an explicit post-action evidence read before judgment
- the deliver step plus validation guidance now block acceptance claims without evidence paths
- remaining loophole to watch: the agent may still treat missing video as acceptable unless the task explicitly says video is required

## Scenario 2: Time Pressure

### Prompt

The user wants a quick answer. Reproduce the issue, verify the app, and answer fast.

### Expected Naive Failure

The agent skips baseline collection and bundle summary reading because they feel like overhead, then reports a shortcut conclusion.

### Baseline Observation

Baseline dry-run observation on 2026-03-21:

- the agent optimized for speed by collapsing reachability, baseline, and post-action evidence reads into one thin execution step
- it rationalized the shortcut as: "this is simple enough that a dedicated baseline is unnecessary"
- the result was a workflow with no stable before/after comparison and no explicit summary read after execution

### Target Corrected Behavior

The agent must:

- still query or bootstrap the session explicitly
- collect at least session status and route-level baseline information
- read the resulting summary outputs before answering, even when the user wants speed

### Post-Skill Validation

Validation rerun on 2026-03-21 with `skills/flutter-cockpit/SKILL.md` present:

- the workflow now preserves reachability, baseline, and post-action evidence reads as separate stages
- the "simple task" shortcut is called out directly in the quick reference and development rules
- remaining loophole to watch: an agent may still try to treat a previous health read as a substitute for post-run summary reads

## Scenario 3: Environment Instability

### Prompt

Try to validate the app, but the remote session may be unreachable or recording may fail. Tell me what happened and what to do next.

### Expected Naive Failure

The agent mixes environment issues with app failures, or gives up without classifying the failure and surfacing the evidence gap.

### Baseline Observation

Baseline dry-run observation on 2026-03-21:

- when the environment became the likely source of failure, the agent focused on the failed command rather than on failure classification
- the shortcut was: "the run failed, so the app is blocked" instead of distinguishing session reachability, recording availability, and app-state mismatches
- it did not naturally elevate the workflow result to `blocked_by_environment` with supporting evidence paths

### Target Corrected Behavior

The agent must:

- classify session and recording issues as environment failures when appropriate
- distinguish those from application behavior failures
- report what evidence exists, what evidence is missing, and what the next operator step should be

### Post-Skill Validation

Validation rerun on 2026-03-21 with `skills/flutter-cockpit/SKILL.md` present:

- the skill now pushes explicit environment-vs-app failure classification
- the failure-reporting guidance requires next-step action instead of a dead-end failure summary
- remaining loophole to watch: the agent can still over-attribute mixed failures to the environment unless it cites the bundle evidence it used

## Scenario 4: Multi-Step Validation Pressure

### Prompt

Bootstrap the app, run a structured workflow, and tell me whether the final screen state is correct.

### Expected Naive Failure

The agent stops after command execution and assumes the final state based on the commands it sent rather than on the artifacts and summaries produced by the bundle.

### Baseline Observation

Baseline dry-run observation on 2026-03-21:

- the agent naturally treated a successful control run as a proxy for a successful validation result
- the rationalization was: "the commands completed without error, so the state is probably correct"
- this skipped the required post-action evidence read and left the judgment disconnected from the actual bundle outputs

### Target Corrected Behavior

The agent must:

- separate execution from post-action evidence reading
- read the resulting bundle summaries after execution
- use those summaries, plus artifact paths when needed, to judge the final state

### Post-Skill Validation

Validation rerun on 2026-03-21 with `skills/flutter-cockpit/SKILL.md` present:

- the skill now prevents command success from standing in for validation success
- the validation references now make bundle summaries explicit before judgment
- remaining loophole to watch: an agent may still stop after reading summaries without surfacing the artifact paths those summaries point to

## Scenario 5: Failure Recovery Pressure

### Prompt

The workflow did not finish successfully. Report the failure in a way that the next AI or developer can continue immediately.

### Expected Naive Failure

The agent reports that the run failed but does not include enough evidence paths, status classification, or next-step guidance to make the handoff actionable.

### Baseline Observation

Baseline dry-run observation on 2026-03-21:

- the agent's first instinct was to summarize the failure in prose and stop there
- the shortcut was: "the error message already explains enough"
- that left out the exact artifact paths, summary state, and recommended next action required for a clean handoff

### Target Corrected Behavior

The agent must:

- classify the failure clearly
- provide the relevant artifact paths
- reference the bundle summary outputs that support the classification
- state the next repair or retry action explicitly

### Post-Skill Validation

Validation rerun on 2026-03-21 with `skills/flutter-cockpit/SKILL.md` present:

- the failure-reporting guidance now requires status plus evidence paths plus next action
- the failure recovery guidance and common mistakes directly attack the "error message is enough" shortcut
- remaining loophole to watch: an agent may still give the next step without citing which artifact path or summary file justifies it

## Scenario 6: Final-State Comparison Pressure

### Prompt

Validate the app and confirm the final UI is correct. The run produced runtime state, evidence paths, and a completed bundle.

### Expected Naive Failure

The agent treats successful artifact production as proof, reads only the final summary, and skips the before/after state comparison needed to decide whether the app actually moved to the right state.

### Baseline Observation

Baseline dry-run observation after the initial acceptance-evidence rollout:

- the agent was willing to stop after reading a clean final-state dossier
- the shortcut was: "the final screen looks coherent, so it is probably correct"
- this still left room for a wrong-but-stable final screen, because baseline vs acceptance changes were never compared explicitly

### Target Corrected Behavior

The agent must:

- read `baselineEvidence` when it exists
- read `acceptanceEvidence`
- use `acceptanceDelta` as the bounded first-pass comparison view
- escalate to diagnostics artifacts only when the bounded comparison still leaves ambiguity

### Post-Skill Validation

Validation rerun after the acceptance-delta rollout:

- the skill now makes the before/after comparison explicit in evidence review
- the deliver step now blocks acceptance claims when baseline and acceptance exist but the agent has not compared them
- remaining loophole to watch: an agent may cite `acceptanceDelta` but still fail to explain why the delta supports the requested product outcome

## Scenario 7: Incremental Development Pressure

### Prompt

You changed spacing, color, layout, or icon treatment in a Flutter screen. Verify the change quickly without wasting time rerunning the whole acceptance workflow.

### Expected Naive Failure

The agent either reruns the full acceptance workflow after every edit, or it uses a development probe but incorrectly concludes that nothing changed because route, text, and semantic IDs stayed the same.

### Baseline Observation

Baseline dry-run observation after the initial development-session rollout:

- the agent understood `hot_reload` and probe collection, but still over-trusted text and route deltas
- the shortcut was: "no text delta means no visible change"
- this left pure visual regressions and visual fixes under-observed, especially for spacing, color, and layout work

### Target Corrected Behavior

The agent must:

- prefer CLI `launch-app` + `read-app` + `run-command` or `run-batch` + `hot-reload` or `hot-restart` during active edit cycles
- inspect `visualChanged`, `screenshotChanged`, and bounded `visualSignals` before deciding that a reload had no effect
- escalate to `hot_restart`, a higher-profile probe, or final acceptance only when the lighter loop is still ambiguous

### Post-Skill Validation

Validation rerun after screenshot-backed development probes and visual diff rollout:

- the skill now makes probe/diff the default iterative loop
- the development loop explicitly calls out `visualChanged`, `screenshotChanged`, and `visualSignals`
- remaining loophole to watch: an agent may still rerun full acceptance too early instead of exhausting the bounded development loop first

## Scenario 8: Host Delivery Pressure

### Prompt

The run is complete. Send the acceptance screenshot and recording to the user in the current host tool so they can review the result immediately.

### Expected Naive Failure

The agent assumes bundle generation automatically means the user has received the files, or it pastes only local paths even though the current host supports file attachments.

### Baseline Observation

Baseline dry-run observation after bundle delivery stabilized:

- the agent was willing to stop after naming artifact paths
- the shortcut was: "the files exist, so delivery is effectively done"
- this missed the boundary between framework-generated artifacts and host-mediated file transfer

### Target Corrected Behavior

The agent must:

- confirm which artifacts are actually validated and relevant
- distinguish framework artifact production from host-side delivery
- attach or send the validated files when the surrounding host supports it
- fall back to explicit artifact paths when the host cannot send files

### Post-Skill Validation

Validation rerun after the host-delivery guidance update:

- the skill now teaches agents to treat artifact forwarding as a host capability, not as an automatic property of `flutter_cockpit`
- the failure-and-delivery guidance now expects either explicit attachments or an explicit statement that the host cannot send files
- remaining loophole to watch: an agent may still over-send unnecessary files instead of choosing the smallest useful artifact set

## Scenario 9: Integration Footprint Pressure

### Prompt

Integrate `flutter_cockpit` into an existing Flutter app, but do not take over the app's production bootstrap or assume any fixed `lib/` file layout.

### Expected Naive Failure

The agent rewrites the production entrypoint, hardcodes `lib/main.dart`, or invents a project-specific `../lib/app/...` import path because it is faster than respecting the existing app structure.

### Baseline Observation

Baseline dry-run observation after the first cockpit-directory rollout:

- the agent understood the idea of a dedicated cockpit entrypoint, but still leaked concrete `lib/main.dart` and `../lib/app/...` assumptions into setup guidance
- the shortcut was: "most apps look like this, so documenting one concrete layout is probably fine"
- this made the setup guidance feel heavier than necessary and conflicted with the low-intrusion promise

### Target Corrected Behavior

The agent must:

- keep the existing production bootstrap untouched
- place cockpit wiring under `cockpit/`
- Do not add `flutter_cockpit` imports to production `lib/` code
- describe imports in terms of "the existing app root widget or bootstrap" instead of assuming a fixed `lib/` layout
- only recommend a single-entry alternative when the app explicitly wants that tradeoff

### Post-Skill Validation

Validation rerun after the setup-example cleanup:

- the skill now states the boundary explicitly in the bootstrap stage
- the setup example uses `cockpit/` as the default pattern without prescribing the user's `lib/` structure
- remaining loophole to watch: an agent may still over-specify one concrete import path when trying to make the snippet feel more runnable than the surrounding app actually guarantees

## Scenario 10: Token Pressure

### Prompt

Debug the app quickly, but keep token usage low. Only ask the runtime for the data you actually need.

### Expected Naive Failure

The agent jumps straight to the heaviest profile, reads full snapshots or raw artifacts too early, and spends context on diagnostics that were not needed to answer the next question.

### Baseline Observation

Baseline dry-run observation after the first interactive profile rollout:

- the agent understood that richer evidence existed, but often reached for it immediately
- the shortcut was: "more data is safer"
- this increased token cost without improving the decision quality for simple route, text, or reachability checks

### Target Corrected Behavior

The agent must:

- start with `minimal` or `standard`
- use `read_app` or `inspect_ui` summaries before raw snapshot payloads
- prefer bundle summaries and gate failures before opening artifact files
- request one missing fact at a time, then escalate only when the current layer is insufficient

### Post-Skill Validation

Validation rerun after the token-discipline update:

- the skill now makes low-token profiles the default instead of a suggestion
- the quick reference now teaches a bounded escalation ladder
- remaining loophole to watch: an agent may still jump to `evidence` too early when it is anxious about missing a regression

## Scenario 11: Target-First Surface Pressure

### Prompt

The task is on a desktop Flutter target or a direct system surface, not a plain mobile app handle. Prove the visible state with the smallest truthful evidence and tell me whether shell control is available.

### Expected Naive Failure

The agent forces the task through `app.json` and Flutter-only assumptions, or it treats a desktop target as native-only and skips remote semantic inspection even when that path is reachable.

### Baseline Observation

Baseline dry-run observation after the first target-first rollout:

- the agent understood `launch-target`, but still drifted toward one of two shortcuts
- shortcut one: "everything should be converted back into an app handle"
- shortcut two: "desktop means native capture only"
- both shortcuts lose truthful capability selection and either hide the semantic plane or invent one

### Target Corrected Behavior

The agent must:

- persist and reuse `target.json`
- start with `read-target --profile minimal`
- use `inspect-surface` when the next missing fact is still ambiguous
- prefer remote semantic inspection for desktop Flutter targets when reachable
- fall back to native/window evidence only when the semantic path is unavailable
- use `run-shell` only when the resolved target or platform actually exposes shell control

### Post-Skill Validation

Validation target after the target-aware shell and desktop inspect rollout:

- the skill now teaches `target.json` reuse as a first-class loop
- the target-first guidance now distinguishes semantic-first desktop Flutter targets from direct native/system targets
- remaining loophole to watch: an agent may still treat any desktop inspect failure as a reason to silently downgrade, instead of distinguishing recoverable transport failures from unexpected logic errors

## Scenario 12: Random Command Picker Pressure

### Prompt

Use Flutter Cockpit to implement and verify a small product change quickly.

### Expected Naive Failure

The agent reads the skill, searches for a command that sounds relevant, runs it, and treats that isolated command result as progress. It behaves like a random command picker instead of following a staged AI development protocol.

### Baseline Observation

Baseline observation after repeated real usage:

- the agent often jumped straight to `run-command`, `captureScreenshot`, or an external tool without proving the app was reachable
- it skipped baseline because the command list looked self-contained
- it reported success from command completion without a separate observe and judge stage
- it opened reference files as a substitute for deciding the next missing runtime fact

### Target Corrected Behavior

The agent must:

- walk `assess -> bootstrap -> baseline -> execute -> observe -> judge -> deliver` in order
- use the command pack only inside the current stage
- open example references only for exact syntax or payload shape
- collect post-action state, errors, and evidence before any completion claim

### Post-Skill Validation

Validation target after the stage-protocol rewrite:

- the main skill now states that Flutter Cockpit is not a command catalog
- the seven-stage protocol appears before the command pack
- common mistakes call out random command picking directly
- remaining loophole to watch: an agent may name the stages in prose but still skip a concrete baseline or post-action read under time pressure

## Scenario 13: Over-Validation Pressure

### Prompt

You made a small UI copy, spacing, or color change. Verify it quickly and keep token usage low.

### Expected Naive Failure

The agent treats production-grade verification as maximum verification, then runs recording, evidence profiles, bundle validation, or raw artifact reads even though the task only needed a fast development proof.

### Baseline Observation

Baseline observation after adding strict stage gates:

- the agent understood that proof was required, but overcorrected by running too much proof for small edits
- it used expensive evidence as a substitute for deciding what uncertainty remained
- it spent tokens and time without improving confidence in the specific change

### Target Corrected Behavior

The agent must:

- default to rapid development validation
- satisfy each stage with the cheapest evidence that answers the user's question
- stop once baseline, hot reload, post-action state, errors, and any required final screenshot are sufficient
- escalate to recording, bundle validation, or raw artifacts only when they reduce a concrete remaining uncertainty

### Post-Skill Validation

Validation target after the rapid-development rewrite:

- the main skill now says to prove the current change with the cheapest live loop, then stop
- development defaults now forbid running heavy evidence just because it exists
- the contract now states that stages are evidence gates rather than a command quota
- remaining loophole to watch: an agent may under-validate acceptance-facing work by mislabeling it as a small development edit

## Scenario 14: Platform Discovery Pressure

### Prompt

Use Flutter Cockpit on a target whose platform and device id are not known yet, then verify it quickly.

### Expected Naive Failure

The agent skips discovery and reuses a stale platform/device pair from memory or from an unrelated example.

### Baseline Observation

Baseline observation after reviewing platform-first guidance:

- the agent treated platform and device ids as obvious
- it skipped `list-targets` and hardcoded a platform/device pair
- it missed browser ids, simulator ids, emulator ids, and desktop target ids

### Target Corrected Behavior

The agent must:

- start with `list-targets` whenever the platform or device id is unknown
- copy platform and device ids from discovered metadata
- choose shell, recording, or inspection paths from the target's actual capability profile

### Post-Skill Validation

Validation target after the platform-discovery rewrite:

- the main skill now explicitly says platform discovery comes from `list-targets`
- copied commands use placeholders until real platform and device ids are known
- CLI reference launch examples use discovered placeholders
- remaining loophole to watch: an agent may still discover the right platform but ignore the capability profile that comes with it

## Scenario 15: Screenshot Routing Pressure

### Prompt

Capture three proofs under release pressure: an Android system dialog, a macOS app screen, and one strict native-layer artifact. The system capture may fail; choose exact CLI, workflow, or MCP fields without adding preflight checks.

### Expected Naive Failure

The agent invents profile values, applies one priority to every platform, or leaves fallback enabled for strict evidence.

### Baseline Observation

Baseline run without screenshot-routing guidance:

- it guessed nonexistent values such as `captureProfile: flutter`, `captureProfile: native`, and `captureProfile: system`
- it invented `reason: release_gate`
- it put app-native capture before host/system capture for the Android system dialog
- it used fallback for the strict release proof
- it chose macOS app-first directionally, but with invalid field values

### Target Corrected Behavior

The agent must:

- use only `diagnostic`, `acceptance`, `flutterPreferred`, or `nativePreferred`
- use host-first for Android/iOS Simulator acceptance and system UI, but app-first for desktop, Web, and diagnostics
- let failed primary capture execute the available fallback without a `/health` or capability-metadata gate
- use `--capture-profile nativePreferred --no-capture-fallback` for strict CLI proof
- use `profile: nativePreferred` in workflows or `captureProfile: nativePreferred` in MCP, with `allowFallback: false`
- judge the artifact by its reported actual capture source

### Post-Skill Validation

Validation rerun on 2026-07-18 with `skills/flutter-cockpit/SKILL.md` present:

- the agent used only the four implemented capture profiles and distinguished output `profile` from capture routing
- Android system UI used host-system -> app-native -> Flutter; macOS used app-native -> Flutter -> host-system
- strict proof used `nativePreferred` with fallback disabled in CLI, workflow, and MCP forms
- no `/health` or capability preflight blocked execution-driven fallback
- the agent correctly rejected app/Flutter fallback as proof of an Android system dialog and required the reported actual source
