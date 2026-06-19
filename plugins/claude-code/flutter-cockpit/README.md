# Flutter Cockpit Claude Code Plugin

This plugin exposes the complete `flutter-cockpit` skill and a local `cockpit` MCP server to Claude Code.

## Install

Install from a local Claude Code plugin marketplace or copy this plugin directory into a marketplace under `plugins/flutter-cockpit`.

Then reload plugins in Claude Code:

```text
/reload-plugins
```

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
