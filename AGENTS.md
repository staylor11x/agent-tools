# AGENTS

This repository is the shared SDK for agent tooling.

## Tooling Rules

- Use skill instructions in `skills/` to decide when to invoke each script.
- Scripts must own MCP/CLI fallback logic and emit consistent machine-readable output.
- Agents must not emit raw `gh` or direct API commands when a script exists.
