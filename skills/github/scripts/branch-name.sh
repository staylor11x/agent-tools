#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE' >&2
Usage: branch-name.sh --title <title> [--number <number>] [--prefix <prefix>] [--max-length <length>]
USAGE
}

json_string() {
  python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$1"
}

emit_error() {
  local message="$1"
  printf '{"ok":false,"error":%s}\n' "$(json_string "$message")"
}

title=""
number=""
prefix=""
max_length="60"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --title) title="$2"; shift 2 ;;
    --number) number="$2"; shift 2 ;;
    --prefix) prefix="$2"; shift 2 ;;
    --max-length) max_length="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) usage; emit_error "Unknown argument: $1"; exit 2 ;;
  esac
done

if [[ -z "$title" ]]; then
  usage
  emit_error "Missing required flag: --title"
  exit 2
fi

if ! [[ "$max_length" =~ ^[0-9]+$ ]] || [[ "$max_length" -le 0 ]]; then
  emit_error "--max-length must be a positive integer"
  exit 2
fi

branch_name="$(python3 - "$title" "$number" "$prefix" "$max_length" <<'PY'
import re
import sys

title = sys.argv[1]
number = sys.argv[2].strip()
prefix = sys.argv[3].strip()
max_len = int(sys.argv[4])

slug = re.sub(r'[^a-z0-9]+', '-', title.lower()).strip('-')
if not slug:
    slug = 'change'

base = slug
if number:
    base = f"{number}-{base}"
if prefix:
    cleaned_prefix = re.sub(r'[^a-z0-9/_-]+', '-', prefix.lower()).strip('-/')
    if cleaned_prefix:
        base = f"{cleaned_prefix}/{base}"

if len(base) > max_len:
    base = base[:max_len].rstrip('-/')

print(base or 'change')
PY
)"

printf '{"ok":true,"branch_name":%s}\n' "$(json_string "$branch_name")"
