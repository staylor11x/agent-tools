#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE' >&2
Usage: upload-issues.sh --owner <owner> --repo <repo> --file <json-file>

Input file format:
[
  {
    "title": "Issue title",
    "body": "Optional body",
    "labels": ["bug", "high-priority"],
    "assignees": ["octocat"]
  }
]
USAGE
}

json_string() {
  python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$1"
}

emit_error() {
  local message="$1"
  printf '{"ok":false,"error":%s}\n' "$(json_string "$message")"
}

owner=""
repo=""
file=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --owner) owner="$2"; shift 2 ;;
    --repo) repo="$2"; shift 2 ;;
    --file) file="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) usage; emit_error "Unknown argument: $1"; exit 2 ;;
  esac
done

if [[ -z "$owner" || -z "$repo" || -z "$file" ]]; then
  usage
  emit_error "Missing required flags: --owner, --repo, --file"
  exit 2
fi

if [[ ! -f "$file" ]]; then
  emit_error "Input file not found: $file"
  exit 2
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
create_issue_script="$script_dir/create-issue.sh"
if [[ ! -x "$create_issue_script" ]]; then
  emit_error "Required script missing or not executable: $create_issue_script"
  exit 1
fi

tmp_items="$(mktemp)"
tmp_results="$(mktemp)"
trap 'rm -f "$tmp_items" "$tmp_results"' EXIT

if ! python3 - "$file" >"$tmp_items" <<'PY'
import json
import sys

path = sys.argv[1]
with open(path, 'r', encoding='utf-8') as f:
    data = json.load(f)

if not isinstance(data, list):
    raise SystemExit('Input JSON must be an array of issue objects')

for idx, item in enumerate(data, 1):
    if not isinstance(item, dict):
        raise SystemExit(f'Entry {idx} is not an object')
    title = item.get('title')
    if not isinstance(title, str) or not title.strip():
        raise SystemExit(f'Entry {idx} is missing a non-empty "title"')

    body = item.get('body', '')
    if body is None:
        body = ''
    if not isinstance(body, str):
        raise SystemExit(f'Entry {idx} has non-string "body"')

    def normalize_list(value, field):
        if value is None:
            return ''
        if isinstance(value, str):
            return value
        if isinstance(value, list) and all(isinstance(v, str) for v in value):
            return ','.join(v for v in value if v)
        raise SystemExit(f'Entry {idx} has invalid "{field}"; expected string or string array')

    labels = normalize_list(item.get('labels', ''), 'labels')
    assignees = normalize_list(item.get('assignees', ''), 'assignees')
    print(json.dumps({
        'index': idx,
        'title': title.strip(),
        'body': body,
        'labels': labels,
        'assignees': assignees,
    }, ensure_ascii=False))
PY
then
  emit_error "Invalid input file format"
  exit 2
fi

while IFS= read -r issue_json; do
  index="$(python3 -c 'import json,sys; print(json.loads(sys.argv[1])["index"])' "$issue_json")"
  title="$(python3 -c 'import json,sys; print(json.loads(sys.argv[1])["title"])' "$issue_json")"
  body="$(python3 -c 'import json,sys; print(json.loads(sys.argv[1])["body"])' "$issue_json")"
  labels="$(python3 -c 'import json,sys; print(json.loads(sys.argv[1])["labels"])' "$issue_json")"
  assignees="$(python3 -c 'import json,sys; print(json.loads(sys.argv[1])["assignees"])' "$issue_json")"

  create_args=(--owner "$owner" --repo "$repo" --title "$title")
  if [[ -n "$body" ]]; then
    create_args+=(--body "$body")
  fi
  if [[ -n "$labels" ]]; then
    create_args+=(--labels "$labels")
  fi
  if [[ -n "$assignees" ]]; then
    create_args+=(--assignees "$assignees")
  fi

  set +e
  response="$($create_issue_script "${create_args[@]}" 2>/dev/null)"
  call_exit=$?
  set -e

  if [[ $call_exit -ne 0 || -z "$response" ]]; then
    response='{"ok":false,"provider":"none","error":"Failed to create issue"}'
  fi

  python3 - "$index" "$response" >>"$tmp_results" <<'PY'
import json
import sys

index = int(sys.argv[1])
response = json.loads(sys.argv[2])
print(json.dumps({'index': index, 'result': response}, ensure_ascii=False))
PY
done <"$tmp_items"

python3 - "$tmp_results" <<'PY'
import json
import sys

path = sys.argv[1]
results = []
created = 0
failed = 0

with open(path, 'r', encoding='utf-8') as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        row = json.loads(line)
        results.append(row)
        if row.get('result', {}).get('ok'):
            created += 1
        else:
            failed += 1

print(json.dumps({
    'ok': failed == 0,
    'total': len(results),
    'created': created,
    'failed': failed,
    'results': results,
}, ensure_ascii=False))
PY
