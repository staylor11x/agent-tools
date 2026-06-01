#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE' >&2
Usage: create-issue.sh --owner <owner> --repo <repo> --title <title> [--body <body>] [--labels <l1,l2>] [--assignees <u1,u2>]
USAGE
}

json_string() {
  python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$1"
}

emit_error() {
  local provider="$1"
  local message="$2"
  printf '{"ok":false,"provider":%s,"error":%s}\n' "$(json_string "$provider")" "$(json_string "$message")"
}

emit_success() {
  local provider="$1"
  local number="$2"
  local url="$3"
  local title="$4"
  printf '{"ok":true,"provider":%s,"issue_number":%s,"issue_url":%s,"title":%s}\n' \
    "$(json_string "$provider")" \
    "${number:-null}" \
    "$(json_string "$url")" \
    "$(json_string "$title")"
}

owner=""
repo=""
title=""
body=""
labels=""
assignees=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --owner) owner="$2"; shift 2 ;;
    --repo) repo="$2"; shift 2 ;;
    --title) title="$2"; shift 2 ;;
    --body) body="$2"; shift 2 ;;
    --labels) labels="$2"; shift 2 ;;
    --assignees) assignees="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) usage; emit_error "none" "Unknown argument: $1"; exit 2 ;;
  esac
done

if [[ -z "$owner" || -z "$repo" || -z "$title" ]]; then
  usage
  emit_error "none" "Missing required flags: --owner, --repo, --title"
  exit 2
fi

mcp_cmd="${AGENT_TOOLS_GITHUB_MCP_CMD:-}"
if [[ -z "$mcp_cmd" ]] && command -v github-mcp >/dev/null 2>&1; then
  mcp_cmd="github-mcp"
fi

if [[ -n "$mcp_cmd" ]]; then
  set +e
  mcp_output="$($mcp_cmd create-issue --owner "$owner" --repo "$repo" --title "$title" --body "$body" --labels "$labels" --assignees "$assignees" 2>/dev/null)"
  mcp_exit=$?
  set -e

  if [[ $mcp_exit -eq 0 && -n "$mcp_output" ]]; then
    parsed="$(python3 -c 'import json,sys
try:
    data=json.loads(sys.stdin.read())
    n=data.get("issue_number", data.get("number"))
    u=data.get("issue_url", data.get("url", ""))
    t=data.get("title", "")
    if u:
        print("{}\t{}\t{}".format("" if n is None else n, u, t))
except Exception:
    pass
' <<<"$mcp_output")"

    if [[ -n "$parsed" ]]; then
      IFS=$'\t' read -r issue_number issue_url issue_title <<<"$parsed"
      emit_success "mcp" "$issue_number" "$issue_url" "${issue_title:-$title}"
      exit 0
    fi
  fi
fi

if ! command -v gh >/dev/null 2>&1; then
  emit_error "none" "GitHub MCP unavailable and gh CLI not installed"
  exit 1
fi

create_args=(issue create --repo "$owner/$repo" --title "$title")
if [[ -n "$body" ]]; then
  create_args+=(--body "$body")
else
  create_args+=(--body "")
fi
if [[ -n "$labels" ]]; then
  IFS=',' read -ra label_array <<<"$labels"
  for label in "${label_array[@]}"; do
    create_args+=(--label "$label")
  done
fi
if [[ -n "$assignees" ]]; then
  IFS=',' read -ra assignee_array <<<"$assignees"
  for assignee in "${assignee_array[@]}"; do
    create_args+=(--assignee "$assignee")
  done
fi

set +e
issue_url="$(gh "${create_args[@]}" 2>/dev/null)"
gh_exit=$?
set -e
if [[ $gh_exit -ne 0 || -z "$issue_url" ]]; then
  emit_error "gh" "Failed to create issue via gh CLI"
  exit 1
fi

set +e
issue_view_json="$(gh issue view "$issue_url" --repo "$owner/$repo" --json number,url,title 2>/dev/null)"
view_exit=$?
set -e

if [[ $view_exit -eq 0 && -n "$issue_view_json" ]]; then
  parsed="$(python3 -c 'import json,sys
try:
    data=json.loads(sys.stdin.read())
    print("{}\t{}\t{}".format(data.get("number", ""), data.get("url", ""), data.get("title", "")))
except Exception:
    pass
' <<<"$issue_view_json")"
  if [[ -n "$parsed" ]]; then
    IFS=$'\t' read -r issue_number parsed_url parsed_title <<<"$parsed"
    emit_success "gh" "$issue_number" "${parsed_url:-$issue_url}" "${parsed_title:-$title}"
    exit 0
  fi
fi

emit_success "gh" "" "$issue_url" "$title"
