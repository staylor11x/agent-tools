---
name: github
description: GitHub automation for issues, PRs, and branch management. Use when creating issues, uploading bulk issues, or generating branch names.
---

# GitHub Skill

Use GitHub tooling from this repository for all issue and PR automation.

## Scripts

| Script | Purpose |
|--------|---------|
| `scripts/upload-issues.sh` | Upload issues from a JSON file |
| `scripts/bulk-issue-upload.sh` | Upload issues from a directory of `.md` files |
| `scripts/branch-name.sh` | Generate a valid branch name from a title |

## Issue Upload (JSON)

Upload issues from a JSON array file:

```bash
skills/github/scripts/upload-issues.sh \
  --owner <owner> \
  --repo <repo> \
  --file <json-file>
```

Input format:

```json
[
  {
    "title": "Issue title",
    "body": "Optional body",
    "labels": ["bug", "high-priority"],
    "assignees": ["octocat"]
  }
]
```

## Bulk Issue Upload (Markdown)

Upload issues from a directory of `.md` files:

```bash
skills/github/scripts/bulk-issue-upload.sh <issues-dir> [--repo OWNER/REPO] [--milestone NAME]
```

Each `.md` file can include optional YAML frontmatter:

```yaml
---
title: Custom title
labels: bug, enhancement
---
```

## Branch Name Generation

Generate a valid branch name from a title:

```bash
skills/github/scripts/branch-name.sh --title <title> [--number <number>] [--prefix <prefix>] [--max-length <length>]
```

Output: `{"ok":true,"branch_name":"42-fix-auth-bug"}`

## Issue Template

Use the template at `templates/issue-template.md` when creating implementation issues.

## Prohibited Direct Commands

- Do **not** write raw `gh issue create`, `gh api`, or direct GitHub REST/GraphQL calls in agent task output.
- Do **not** bypass the scripts even if `gh` is available.
