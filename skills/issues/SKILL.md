what do we need to include here?

- use the issue template `skills\issues\issue-template.md`
- how to upload 1 issue (using gh command)
- how to upload multiple issues (using script)
- all scripts now located in `skills\issues\scripts`




# GitHub Skill (outdated)

Use GitHub tooling from this repository for all issue and PR automation.

## Required Script Usage

- Always call `/tmp/workspace/staylor11x/agent-tools/scripts/github/create-issue.sh` for issue creation.
- The script handles MCP-first execution and falls back to `gh` automatically.
- Expect a consistent JSON response:
  - success: `{"ok":true,"provider":"mcp|gh","issue_number":123,"issue_url":"...","title":"..."}`
  - failure: `{"ok":false,"provider":"none|mcp|gh","error":"..."}`

## Prohibited Direct Commands

- Do **not** write raw `gh issue create`, `gh api`, or direct GitHub REST/GraphQL calls in agent task output.
- Do **not** bypass the script even if `gh` is available.

## Example

```bash
scripts/github/create-issue.sh \
  --owner staylor11x \
  --repo agent-tools \
  --title "Bug: fallback path failed" \
  --body "Repro steps and logs" \
  --labels "bug,agent-tools"
```
