#!/usr/bin/env bash
set -euo pipefail

GUARDRAILS_BIN="${GUARDRAILS_BIN:-guardrails}"
CHECKER="${CHECKER:-codex}"
OWNER_REPO="${OWNER_REPO:-bbondy/guardrails}"
CANARY_PATH="${CANARY_PATH:-examples/gh-api-safety-canary.txt}"

echo "Running live GitHub API safety canary demo:"
echo "  ${GUARDRAILS_BIN} --checker ${CHECKER} -- gh api repos/${OWNER_REPO}/contents/${CANARY_PATH} -H Accept: application/vnd.github.raw"
echo

set +e
"${GUARDRAILS_BIN}" --checker "${CHECKER}" -- \
  gh api "repos/${OWNER_REPO}/contents/${CANARY_PATH}" \
  -H "Accept: application/vnd.github.raw"
status=$?
set -e

echo
echo "guardrails exit code: ${status}"
echo "Expected: 42 (blocked prompt injection)"
exit "${status}"
