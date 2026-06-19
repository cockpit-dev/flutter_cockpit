# Agent Integrations

Flutter Cockpit ships one canonical AI workflow at `skills/flutter-cockpit/SKILL.md` and host-native adapters for common coding agents. Keep the canonical skill as the source of truth; packaged skill adapters carry a synced copy so installed plugins still work outside this repository.

## Codex

Codex supports installable plugins with `.codex-plugin/plugin.json`.

Repository asset:

```text
plugins/codex/flutter-cockpit
```

The plugin exposes:

- `skills/flutter-cockpit` as a complete Codex skill.
- `.mcp.json` with `flutterCockpit -> dart run cockpit serve-mcp`.

For direct MCP setup without installing the plugin:

```bash
codex mcp add flutterCockpit -- dart run cockpit serve-mcp
```

## Claude Code

Claude Code supports plugins with `.claude-plugin/plugin.json`, skills, and `.mcp.json`.

Repository asset:

```text
plugins/claude-code/flutter-cockpit
```

The plugin exposes:

- `skills/flutter-cockpit` as a complete Claude Code skill.
- `.mcp.json` with `flutter-cockpit -> dart run cockpit serve-mcp`.

For direct MCP setup without installing the plugin:

```bash
claude mcp add --transport stdio flutter-cockpit -- dart run cockpit serve-mcp
```

## Cursor

Cursor uses project rules rather than this repository's plugin manifest.

Repository asset:

```text
.cursor/rules/flutter-cockpit.mdc
```

For MCP, add a global or project `.cursor/mcp.json` entry:

```json
{
  "mcpServers": {
    "flutter-cockpit": {
      "type": "stdio",
      "command": "dart",
      "args": ["run", "cockpit", "serve-mcp"]
    }
  }
}
```

## Kiro

Kiro uses steering documents for project guidance.

Repository asset:

```text
.kiro/steering/flutter-cockpit.md
```

If the installed Kiro version supports MCP configuration, add `dart run cockpit serve-mcp` using its current MCP settings UI or config file. Otherwise use the CLI commands from the steering file.

## OpenCode

OpenCode can discover Agent Skills from `.agents/skills/<name>/SKILL.md` and configures MCP servers through the `mcp` option. This repository uses `.agents/skills/flutter-cockpit` for the full on-demand skill and `opencode.json` for the local MCP server.

Repository asset:

```text
opencode.json
.agents/skills/flutter-cockpit
```

The repo-local config loads normal project instructions and the local MCP server:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "instructions": ["AGENTS.md"],
  "mcp": {
    "flutterCockpit": {
      "type": "local",
      "command": ["dart", "run", "cockpit", "serve-mcp"],
      "enabled": true
    }
  }
}
```

The skill body stays out of always-on instructions so OpenCode can load it only when a Flutter Cockpit task needs it.

## OMP / Oh My Pi

OMP discovers Agent Skills from `.agents/skills/<name>/SKILL.md`. The repository includes the native project skill here:

```text
.agents/skills/flutter-cockpit
```

If OMP is configured to import MCP servers from repo config, use the same `dart run cockpit serve-mcp` server. Otherwise run Flutter Cockpit through the CLI commands in the skill.

## Verification

After installing any adapter:

1. Restart or reload the host so it rescans plugins, skills, rules, or steering files.
2. Ask the host to load the `flutter-cockpit` skill, or read `skills/flutter-cockpit/SKILL.md` for repo-local rule/steering adapters.
3. Run `dart run cockpit list-targets`.
4. If MCP is configured, verify the host can see the Flutter Cockpit MCP tools.
5. Keep app proof lightweight: baseline read, action, post-action read, current errors, and screenshot only when visible evidence matters.
