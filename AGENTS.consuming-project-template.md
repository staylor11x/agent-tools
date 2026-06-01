# AGENTS

Use the shared agent-tools SDK for all tooling operations.

## Setup

- Add as submodule: `.agent-tools/` (repository: `staylor11x/agent-tools`).

## Required Usage

- Use `.agent-tools/scripts/` scripts for GitHub/Snyk/Jira actions.
- Read `.agent-tools/skills/` files before running tooling commands.
- Do not write raw `gh` commands or direct API calls when a matching script exists.
