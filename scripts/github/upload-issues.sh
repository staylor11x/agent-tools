#!/usr/bin/env bash
# ==============================================================================
# upload-issues.sh — Bulk GitHub issue uploader for personal-cloud
#
# Origin: Adapted from staylor11x/spider-solitaire:create-issue.sh
#   - Original: processes one .md file per call; extracts title from first H1,
#     body from everything after it; passes labels and assignee as positional
#     arguments; always assigns to @me.
#   - Reused:   H1 title extraction, body extraction, gh issue create pattern.
#   - Adapted:  bulk directory processing, YAML frontmatter for labels, milestone
#     flag, repo auto-detection via gh repo view, structured summary output,
#     accumulated error handling (does not stop on first failure).
#   - Dropped:  interactive assignee argument; issues are never auto-assigned.
#
# Usage:
#   ./scripts/upload-issues.sh <issues-dir> [--repo OWNER/REPO] [--milestone NAME]
#
#   issues-dir         Directory containing .md issue definition files.
#   --repo OWNER/REPO  Target repository. Defaults to current repo (gh repo view).
#   --milestone NAME   Milestone name to attach to every issue created. The
#                      milestone must already exist on the target repository.
#   e.g. 
#   sh scripts/upload-issues.sh milestones/spotify-backend/ --repo staylor11x/personal-site --milestone "Spotify-Backend"
#
# Input file format: see scripts/README.md
#
# Requirements: bash 4+, gh CLI (authenticated with repo scope)
# ==============================================================================

set -uo pipefail

ISSUES_DIR=""
REPO=""
MILESTONE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --repo)
            REPO="$2"
            shift 2
            ;;
        --milestone)
            MILESTONE="$2"
            shift 2
            ;;
        -*)
            echo "Error: Unknown option: $1" >&2
            echo "Usage: $0 <issues-dir> [--repo OWNER/REPO] [--milestone NAME]" >&2
            exit 1
            ;;
        *)
            if [[ -z "$ISSUES_DIR" ]]; then
                ISSUES_DIR="$1"
            else
                echo "Error: Unexpected argument: $1" >&2
                exit 1
            fi
            shift
            ;;
    esac
done

if [[ -z "$ISSUES_DIR" ]]; then
    echo "Error: issues-dir is required." >&2
    echo "Usage: $0 <issues-dir> [--repo OWNER/REPO] [--milestone NAME]" >&2
    exit 1
fi

if [[ ! -d "$ISSUES_DIR" ]]; then
    echo "Error: '$ISSUES_DIR' is not a directory or does not exist." >&2
    exit 1
fi

# Resolve repository — detect from git context if not specified
if [[ -z "$REPO" ]]; then
    if ! REPO=$(gh repo view --json nameWithOwner --jq '.nameWithOwner' 2>/dev/null); then
        echo "Error: Could not detect current repository." >&2
        echo "       Run from within a git repo or pass --repo OWNER/REPO." >&2
        exit 1
    fi
fi

echo "Repository: $REPO"
[[ -n "$MILESTONE" ]] && echo "Milestone:  $MILESTONE"
echo ""

# Collect .md files in alphabetical order
mapfile -t FILES < <(find "$ISSUES_DIR" -maxdepth 1 -name "*.md" | sort)

if [[ ${#FILES[@]} -eq 0 ]]; then
    echo "Error: No .md files found in '$ISSUES_DIR'." >&2
    exit 1
fi

echo "Found ${#FILES[@]} issue file(s)."
echo ""

CREATED_URLS=()
FAILED_FILES=()

for FILE in "${FILES[@]}"; do
    BASENAME=$(basename "$FILE")

    # Detect optional YAML frontmatter (file must start with exactly ---)
    HAS_FRONTMATTER=0
    if [[ "$(head -1 "$FILE")" == "---" ]]; then
        HAS_FRONTMATTER=1
    fi

    # Parse frontmatter fields (text between opening and closing ---)
    FM_TITLE=""
    FM_LABELS=""
    if [[ "$HAS_FRONTMATTER" -eq 1 ]]; then
        FRONTMATTER=$(awk 'NR==1{next} /^---$/{exit} {print}' "$FILE")
        FM_TITLE=$(printf '%s\n' "$FRONTMATTER" | grep "^title:" | head -1 \
            | sed 's/^title:[[:space:]]*//' | tr -d "\"'")
        FM_LABELS=$(printf '%s\n' "$FRONTMATTER" | grep "^labels:" | head -1 \
            | sed 's/^labels:[[:space:]]*//' | tr -d "\"'")
    fi

    # Resolve title: frontmatter field > first H1 > filename without extension
    TITLE="$FM_TITLE"
    if [[ -z "$TITLE" ]]; then
        TITLE=$(grep "^# " "$FILE" | head -1 | sed 's/^# //')
    fi
    if [[ -z "$TITLE" ]]; then
        TITLE=$(basename "$FILE" .md)
    fi

    # Extract body
    if [[ "$HAS_FRONTMATTER" -eq 1 ]]; then
        # Body is everything after the closing ---
        BODY=$(awk 'BEGIN{c=0} /^---$/{c++; if(c==2){body=1; next}} body' "$FILE")
    else
        # Mirrors spider-solitaire: everything after the first H1 line
        BODY=$(sed '1,/^# /d' "$FILE")
        [[ -z "$BODY" ]] && BODY=$(cat "$FILE")
    fi

    echo "Uploading: $BASENAME"
    echo "  Title:  $TITLE"
    [[ -n "$FM_LABELS" ]] && echo "  Labels: $FM_LABELS"

    GH_ARGS=(--repo "$REPO" --title "$TITLE" --body "$BODY")
    [[ -n "$FM_LABELS" ]] && GH_ARGS+=(--label "$FM_LABELS")
    [[ -n "$MILESTONE" ]] && GH_ARGS+=(--milestone "$MILESTONE")

    URL=$(gh issue create "${GH_ARGS[@]}" 2>&1)
    EXIT_CODE=$?

    if [[ "$EXIT_CODE" -ne 0 ]]; then
        echo "  ERROR: Failed to create issue." >&2
        echo "         $URL" >&2
        FAILED_FILES+=("$BASENAME")
    else
        echo "  Created: $URL"
        CREATED_URLS+=("$URL")
    fi

    echo ""
done

echo "=============================="
echo "Summary"
echo "=============================="
echo "Created: ${#CREATED_URLS[@]}"
echo "Failed:  ${#FAILED_FILES[@]}"
echo ""

if [[ ${#CREATED_URLS[@]} -gt 0 ]]; then
    echo "Created issues:"
    for URL in "${CREATED_URLS[@]}"; do
        echo "  $URL"
    done
fi

if [[ ${#FAILED_FILES[@]} -gt 0 ]]; then
    echo ""
    echo "Failed files:"
    for F in "${FAILED_FILES[@]}"; do
        echo "  $F"
    done
    exit 1
fi
