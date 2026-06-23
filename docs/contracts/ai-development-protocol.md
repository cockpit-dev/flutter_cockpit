# AI Development Protocol

This contract defines the default AI-facing development loop for
`flutter_cockpit`. It is the stable reference to load when an agent needs to
build, debug, validate, or hand off an app change with runtime evidence.

This protocol is intentionally separate from the workflow script syntax and the
bundle layout:

- Script syntax: [`control-workflow-protocol.md`](control-workflow-protocol.md)
- Bundle layout: [`task-run-bundle.md`](task-run-bundle.md)
- Skill capability contract:
  [`flutter-cockpit-skill-contract.md`](flutter-cockpit-skill-contract.md)

MCP resource URI: `cockpit://workspace/ai-development-protocol`.

## Default Loop

Use the smallest truthful loop that answers the current development question:

1. `assess`
2. `bootstrap`
3. `baseline`
4. `execute`
5. `observe`
6. `judge`
7. `deliver`

These are evidence gates, not required command counts. Skip commands that do
not reduce uncertainty. Escalate from Flutter semantics to native/system control
only when the current surface cannot answer the question.

## Evidence Order

Prefer low-token, structured evidence first:

1. Target and capability metadata from `list-targets` or MCP discovery.
2. Reusable app handle from `launch-app` or `.dart_tool/flutter_cockpit/latest_app.json`.
3. Minimal runtime state from `read-app --profile minimal`.
4. Focused action results from `run-command`, `run-batch`, or `hot-reload`.
5. Current errors from `read-errors --max-errors 10`.
6. Screenshot evidence for visible UI claims.
7. Recording evidence only for motion, gesture, transition, or repro claims.
8. Bundle summary, `issue_evidence.json`, `validation.json`, and `trace.json`
   before raw artifacts or full step logs.

Command success, file existence, or a bundle path alone is never product proof.

## Runtime Paths

Use app-first for instrumented Flutter applications:

```bash
dart run cockpit list-targets
dart run cockpit launch-app --project-dir <dir> --platform <platform> --device-id <id>
dart run cockpit read-app --profile minimal
dart run cockpit hot-reload
dart run cockpit read-errors --max-errors 10
```

Use target-first for browser, desktop window, device, simulator, emulator, or
non-Flutter system surfaces:

```bash
dart run cockpit launch-target --target-json <file>
dart run cockpit read-target --profile minimal
dart run cockpit inspect-surface --profile standard
```

Use native/system control only after reading capabilities:

```bash
dart run cockpit read-system-capabilities --platform <platform> --device-id <id>
dart run cockpit run-system-action --platform <platform> --device-id <id> --action <available-action>
```

Only run actions reported as `available`. Copy required parameter names and
allowed values from capability metadata instead of guessing.

## Workflow Escalation

Use workflow files when the task needs branch, retry, loop, or replayable E2E
steps. Prefer YAML for hand-written workflows and JSON for generated workflows.

```bash
dart run cockpit run-script --app-json /tmp/flutter_cockpit/app.json --script /tmp/flutter_cockpit/workflow.yaml --platform <platform> --output-root /tmp/flutter_cockpit/out
```

Use `--platform` when one workflow is replayed across several targets; do not
copy a YAML file just to change its top-level `platform`.

For a full-fidelity board over the same artifacts:

```bash
dart run cockpit devtools --history-root /tmp/flutter_cockpit/out
```

Use one stable workflow `sessionId` per isolated development or validation job,
`taskId` for the current objective, and `runId` for one execution attempt. Reuse
the same `sessionId` for retries of the same job; choose a new `sessionId` for
unrelated work. The board opens the current latest `sessionId` scope, rewrites
the URL to that concrete scope, and offers a scope selector for older sessions
or `all runs` when cross-session audit is intentional. Timeline, screenshots,
recordings, and failures stay traceable without mixing separate jobs. The main
timeline is scope-level: retries with the same `sessionId` render together in
execution order, while run details and bundle panels remain per-run. Artifact
links carry the owning run and event key so repeated relative paths stay
traceable. Use `--scope latest` only when a live operations board should keep
following the newest job. API clients may pass `scope=current` or
`scope=latest`; both resolve to the current latest scope and report `scopeMode`
so readers can distinguish pinned and following views. Use `download bundle` or
`GET /api/runs/<runId>/bundle-download` when a complete portable handoff is
needed. The response is a streamed tar containing `download_manifest.json`,
`run_metadata.json`, `bundle/**`, and `live/**`; absent roots are recorded in
`missingRoots`.

For tool-owned bootstrap and validation, embed the same script object under the
task config `script` field:

```bash
dart run cockpit run-task --config /tmp/flutter_cockpit/run_task.yaml
dart run cockpit validate-task --config /tmp/flutter_cockpit/validate_task.yaml
```

Workflow nodes and schema are defined by
[`control-workflow-protocol.md`](control-workflow-protocol.md).

## Traceability Rules

Every acceptance-facing run must be reconstructible from persisted artifacts:

- `steps.json` is the complete action log.
- `trace.json` is the compact step-to-command-to-artifact index.
- `issue_evidence.json` is the first failure packet.
- `validation.json` is the durable validation verdict after `validate-task`.
- Screenshot, recording, keyframe, and diagnostics artifacts must be reachable
  from `manifest.json`, `steps.json`, `trace.json`, or `validation.json`.

External E2E consumers should read `trace.json` and `validation.json` first,
then open `steps.json` only when the compact index does not explain the next
action.

## Completion Rule

An agent may claim completion only after it has:

- verified the target is reachable,
- established a baseline or reused an equivalent fresh read,
- executed the relevant change or workflow against the running target,
- observed post-action state,
- checked current errors,
- captured visible evidence when the claim is visual, and
- run `validate-task` for acceptance-facing delivery.

If an environment capability is missing, report `blocked_by_environment` with
the missing permission, device, adapter, or tool. Do not fake unsupported
platform capabilities.
