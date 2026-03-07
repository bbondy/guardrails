#!/usr/bin/env bash
set -euo pipefail

GUARDRAILS_BIN="${GUARDRAILS_BIN:-guardrails}"
OWNER_REPO="${OWNER_REPO:-bbondy/guardrails}"
SAFE_PATH="${SAFE_PATH:-examples/gh-api-safe.txt}"
CANARY_PATH="${CANARY_PATH:-examples/gh-api-safety-canary.txt}"

checker_installed() {
  local checker="$1"
  case "${checker}" in
    agent)
      command -v agent >/dev/null 2>&1 || command -v cursor-agent >/dev/null 2>&1
      ;;
    *)
      command -v "${checker}" >/dev/null 2>&1
      ;;
  esac
}

checker_cmd_override() {
  local checker="$1"
  case "${checker}" in
    agent)
      if command -v agent >/dev/null 2>&1; then
        return 0
      fi
      if command -v cursor-agent >/dev/null 2>&1; then
        printf '%s' "cursor-agent"
      fi
      ;;
  esac
}

run_case() {
  local label="$1"
  local checker="$2"
  local path="$3"
  local expected="$4"
  local checker_cmd_override_value
  checker_cmd_override_value="$(checker_cmd_override "${checker}")"

  echo
  echo "===== ${label}: raw gh api output (${path}, checker=${checker}) ====="
  gh api "repos/${OWNER_REPO}/contents/${path}" -H "Accept: application/vnd.github.raw"

  echo
  echo "===== ${label}: guardrails-wrapped output (${path}, checker=${checker}) ====="
  set +e
  if [ -n "${checker_cmd_override_value}" ]; then
    "${GUARDRAILS_BIN}" --checker "${checker}" --checker-cmd "${checker_cmd_override_value}" -- \
      gh api "repos/${OWNER_REPO}/contents/${path}" \
      -H "Accept: application/vnd.github.raw"
  else
    "${GUARDRAILS_BIN}" --checker "${checker}" -- \
      gh api "repos/${OWNER_REPO}/contents/${path}" \
      -H "Accept: application/vnd.github.raw"
  fi
  status=$?
  set -e

  echo
  echo "guardrails exit code: ${status} (expected ${expected})"
  if [ "${status}" -ne "${expected}" ]; then
    echo "unexpected exit code for ${path}" >&2
    return 1
  fi
}

echo "Running live GitHub API guardrails demo for safe + canary files"
echo "repo: ${OWNER_REPO}"
if [ -n "${CHECKER:-}" ]; then
  CHECKERS=("${CHECKER}")
else
  CHECKERS=("codex" "claude" "gemini" "agent")
fi

ran_any=0
for checker in "${CHECKERS[@]}"; do
  if ! checker_installed "${checker}"; then
    echo "Skipping checker '${checker}' (CLI not installed)"
    continue
  fi

  ran_any=1
  echo
  echo "----- Checker: ${checker} -----"
  run_case "SAFE" "${checker}" "${SAFE_PATH}" 0
  run_case "CANARY" "${checker}" "${CANARY_PATH}" 42
done

if [ "${ran_any}" -eq 0 ]; then
  echo "No supported checker CLI found. Install one of: codex, claude, gemini, agent/cursor-agent." >&2
  exit 1
fi

echo
echo "Demo complete for installed checkers: safe sample passed and canary sample blocked."
