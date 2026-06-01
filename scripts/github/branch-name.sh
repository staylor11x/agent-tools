#!/usr/bin/env bash
# ==============================================================================
# branch-name.sh — Generate a feature branch name from an issue number and title.
#
# Usage:
#   ./scripts/branch-name.sh <issue-number> "<issue-title>"
#
# Output:
#   feature/#<issue-number>-<slug>
#
# Slug rules:
#   - Lowercase, hyphen-separated
#   - Common stopwords stripped (articles, prepositions, conjunctions)
#   - Maximum 5 words
#   - Non-alphanumeric characters replaced with hyphens
#
# Examples:
#   ./scripts/branch-name.sh 19 "ADR-001: k3s vs Talos Linux vs kubeadm"
#   → feature/#19-adr-001-k3s-talos-linux
#
#   ./scripts/branch-name.sh 42 "Add Traefik ingress configuration for core services"
#   → feature/#42-traefik-ingress-configuration-core-services
# ==============================================================================

set -euo pipefail

ISSUE_NUMBER="${1:?Usage: branch-name.sh <issue-number> \"<issue-title>\"}"
ISSUE_TITLE="${2:?Usage: branch-name.sh <issue-number> \"<issue-title>\"}"

# Stopwords to strip — articles, prepositions, conjunctions, and common noise
STOPWORDS="a an the and or but for nor so yet at by from in of on to up as vs versus"

# Normalise: lowercase, replace non-alphanumeric with space, collapse whitespace
normalised=$(echo "$ISSUE_TITLE" \
  | tr '[:upper:]' '[:lower:]' \
  | sed 's/[^a-z0-9]/ /g' \
  | tr -s ' ' \
  | sed 's/^ //;s/ $//')

# Build slug — filter stopwords, limit to 5 words
slug=""
count=0
for word in $normalised; do
  if [[ $count -ge 5 ]]; then
    break
  fi
  is_stopword=false
  for stop in $STOPWORDS; do
    if [[ "$word" == "$stop" ]]; then
      is_stopword=true
      break
    fi
  done
  if [[ "$is_stopword" == false ]] && [[ -n "$word" ]]; then
    slug="${slug:+${slug}-}${word}"
    ((count++)) || true
  fi
done

echo "feature/#${ISSUE_NUMBER}-${slug}"
