#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ISSUES_FILE="${ISSUES_FILE:-docs/github-project-issues.tsv}"
if [[ "$ISSUES_FILE" != /* ]]; then
  ISSUES_FILE="$ROOT_DIR/$ISSUES_FILE"
fi

OWNER="${OWNER:-aarthvr-b}"
REPO="${REPO:-Blockrendum}"
PROJECT_TITLE="${PROJECT_TITLE:-Blockrendum}"
PROJECT_NUMBER="${PROJECT_NUMBER:-}"
SKIP_PROJECT_ADD="${SKIP_PROJECT_ADD:-0}"

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

ensure_label() {
  local name="$1"
  local color="$2"

  if gh label list --repo "$OWNER/$REPO" --limit 200 --json name --jq '.[].name' | grep -Fxq "$name"; then
    return 0
  fi

  gh label create "$name" --repo "$OWNER/$REPO" --color "$color" >/dev/null
}

ensure_issue() {
  local title="$1"
  local labels="$2"
  local body="$3"

  local existing
  existing="$(gh issue list --repo "$OWNER/$REPO" --state all --search "\"$title\" in:title" --json title,number --jq '.[] | select(.title == "'"$title"'") | .number' | head -n1 || true)"
  if [[ -n "$existing" ]]; then
    echo "$existing"
    return 0
  fi

  local issue_url
  issue_url="$(gh issue create \
    --repo "$OWNER/$REPO" \
    --title "$title" \
    --label "$labels" \
    --body "$body")"

  basename "$issue_url"
}

find_project_number() {
  gh project list --owner "$OWNER" --format json --jq '.projects[]? | select(.title == "'"$PROJECT_TITLE"'") | .number' | head -n1
}

add_issue_to_project() {
  local issue_number="$1"
  local project_number="$2"

  if gh project item-list "$project_number" --owner "$OWNER" --format json --jq '.items[]? | select(.content.number == '"$issue_number"' and .content.repository == "'"$OWNER/$REPO"'") | .id' | grep -q .; then
    return 0
  fi

  gh project item-add "$project_number" --owner "$OWNER" --url "https://github.com/$OWNER/$REPO/issues/$issue_number" >/dev/null
}

main() {
  require_cmd gh
  require_cmd python3

  if [[ -z "${GH_TOKEN:-}" ]] && ! gh auth status >/dev/null 2>&1; then
    echo "GitHub authentication is missing. Either export GH_TOKEN or run 'gh auth login' first." >&2
    exit 1
  fi

  local project_number="$PROJECT_NUMBER"
  if [[ "$SKIP_PROJECT_ADD" != "1" && -z "$project_number" ]]; then
    project_number="$(find_project_number || true)"
    if [[ -z "$project_number" ]]; then
      cat >&2 <<EOF
Could not find GitHub Project titled '$PROJECT_TITLE' for owner '$OWNER'.

Either:
- set PROJECT_NUMBER explicitly, or
- grant the token the read:project scope so gh can resolve the project by title.
EOF
      exit 1
    fi
  fi

  ensure_label "area:setup" "0e8a16"
  ensure_label "area:api" "1d76db"
  ensure_label "area:data" "5319e7"
  ensure_label "area:auth" "0052cc"
  ensure_label "area:voting" "fbca04"
  ensure_label "area:blockchain" "b60205"
  ensure_label "area:admin" "d93f0b"
  ensure_label "area:docs" "c2e0c6"
  ensure_label "size:xs" "bfdadc"
  ensure_label "size:s" "bfd4f2"
  ensure_label "type:task" "7057ff"
  ensure_label "type:decision" "c5def5"
  ensure_label "type:spike" "f9d0c4"
  ensure_label "blocked" "d73a4a"

  python3 - "$ISSUES_FILE" <<'PY' | while IFS= read -r -d '' title && IFS= read -r -d '' labels && IFS= read -r -d '' body; do
import csv
import sys

with open(sys.argv[1], newline="", encoding="utf-8") as fh:
    reader = csv.DictReader(fh, delimiter="\t")
    for row in reader:
        body = row["body"].replace("\\n", "\n")
        sys.stdout.buffer.write(row["title"].encode("utf-8"))
        sys.stdout.buffer.write(b"\0")
        sys.stdout.buffer.write(row["labels"].encode("utf-8"))
        sys.stdout.buffer.write(b"\0")
        sys.stdout.buffer.write(body.encode("utf-8"))
        sys.stdout.buffer.write(b"\0")
PY
    issue_number="$(ensure_issue "$title" "$labels" "$body")"
    if [[ "$SKIP_PROJECT_ADD" == "1" ]]; then
      echo "Created or reused issue #$issue_number: $title"
    else
      add_issue_to_project "$issue_number" "$project_number"
      echo "Added issue #$issue_number to project: $title"
    fi
  done
}

main "$@"
