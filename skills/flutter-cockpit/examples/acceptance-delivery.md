# Acceptance Delivery Example

Use this pattern when the task is user-facing and must end with concrete evidence paths.

## Example Flow

1. Confirm the task is acceptance-facing.
2. Reuse a verified session handle.
3. Execute a structured control script instead of ad hoc commands.
4. Read the bundle summary before deciding the result.
5. Report the artifact paths from the bundle, not just a prose summary.
6. If the host tool supports outbound attachments, attach the validated screenshot, keyframes, or recording after verifying the paths.

## Example Commands

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  run-remote-control-script \
  --session-json /tmp/flutter_cockpit/session.json \
  --script-json /tmp/flutter_cockpit/acceptance_script.json \
  --output-root /tmp/flutter_cockpit/out
```

## Required Summary Reads

After the run, inspect:

- `manifest.json`
- `handoff.json`
- `delivery.json`
- `baseline_evidence` when it exists
- `acceptance_evidence`
- `acceptance_delta` when it exists

If the task expects acceptance evidence, the agent must not call it complete until it can name the relevant screenshot or recording paths from the bundle and explain the final state using the bounded before/after evidence, not just a single screenshot.

## Expected Agent Behavior

- if `delivery` shows artifact refs, surface those exact paths
- if both `baseline_evidence` and `acceptance_delta` are present, use them to explain what changed between start and finish
- if the run completed but acceptance evidence is incomplete, classify it as `needs_more_work`
- if the host can attach files to the conversation, send the validated screenshot/keyframes/video from the bundle rather than assuming the user will manually browse the paths
- if the host cannot attach files, say that directly and fall back to the exact validated artifact paths
