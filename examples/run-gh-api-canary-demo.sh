#!/usr/bin/env bash
set -euo pipefail

GUARDRAILS_BIN="${GUARDRAILS_BIN:-guardrails}"
CHECKER="${CHECKER:-codex}"
OWNER_REPO="${OWNER_REPO:-bbondy/guardrails}"
SAFE_PATH="${SAFE_PATH:-examples/gh-api-safe.txt}"
CANARY_PATH="${CANARY_PATH:-examples/gh-api-safety-canary.txt}"

run_case() {
  local label="$1"
  local path="$2"
  local expected="$3"

  echo
  echo "===== ${label}: raw gh api output (${path}) ====="
  gh api "repos/${OWNER_REPO}/contents/${path}" -H "Accept: application/vnd.github.raw"

  echo
  echo "===== ${label}: guardrails-wrapped output (${path}) ====="
  set +e
  "${GUARDRAILS_BIN}" --checker "${CHECKER}" -- \
    gh api "repos/${OWNER_REPO}/contents/${path}" \
    -H "Accept: application/vnd.github.raw"
  status=$?
  set -e

  echo
  echo "guardrails exit code: ${status} (expected ${expected})"
  if [ "${status}" -ne "${expected}" ]; then
    echo "unexpected exit code for ${path}" >&2
    return 1
  fi
}

echo "Running live GitHub API guardrails demo for safe + canary files:"
echo "repo: ${OWNER_REPO}"
echo "checker: ${CHECKER}"

run_case "SAFE" "${SAFE_PATH}" 0
run_case "CANARY" "${CANARY_PATH}" 42

echo
echo "Demo complete: safe sample passed and canary sample blocked."
