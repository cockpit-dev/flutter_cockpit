# Flutter Cockpit Codex Plugin

This plugin exposes the complete `flutter-cockpit` skill and a local `cockpit` MCP server to Codex.

## Install

Use it as a local plugin or add it to a Codex marketplace that points at `plugins/codex/flutter-cockpit`.

The MCP server starts with:

```bash
dart run cockpit serve-mcp
```

Install the Dart packages first so `cockpit` resolves in the target workspace.

## Source Of Truth

The full AI development loop is bundled at:

```text
skills/flutter-cockpit/SKILL.md
```
