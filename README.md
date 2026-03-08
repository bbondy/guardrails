# guardrails

[![CI](https://github.com/bbondy/guardrails/actions/workflows/ci.yml/badge.svg)](https://github.com/bbondy/guardrails/actions/workflows/ci.yml)

<img src="assets/icons/png/guardrails-256.png" alt="guardrails logo" width="180" />

A native Rust CLI that wraps another CLI, buffers `stdout` and `stderr`, and either blocks unsafe output (`check` mode) or minimally filters unsafe content (`filter` mode).

Detailed implementation guide: [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md)

## Install

Via npmjs:

```bash
npm install -g @brianbondy/guardrails
```

Via install script:

```bash
curl -fsSL https://raw.githubusercontent.com/bbondy/guardrails/main/install.sh | sh
```

Optional install directory:

```bash
curl -fsSL https://raw.githubusercontent.com/bbondy/guardrails/main/install.sh | INSTALL_DIR="$HOME/.local/bin" sh
```

## Build

Local (requires Rust toolchain):

```bash
cargo build --release
./target/release/guardrails --help
```

Developer and release workflows are documented in [`docs/DEVELOPMENT.md`](docs/DEVELOPMENT.md).

## How it works (`check` mode)

1. `guardrails` executes a wrapped command.
2. Wrapped-command stdin is forwarded to the wrapped process.
3. It captures full command output (buffered, not streamed). By default it captures `stdout` and `stderr` separately; with `--pty` it captures a merged PTY stream for terminal-style formatting.
4. It invokes the selected checker tool (`codex`, `claude`, `gemini`, or `agent`) in non-interactive mode from inside `guardrails`.
5. If verdict is `unsafe`, it exits with code `42` and does not forward wrapped output.
6. If verdict is `safe`, it re-emits the same bytes to `stdout`/`stderr` and exits with the wrapped command's status.
7. If no wrapped command is provided, it reads fully buffered stdin, checks it, and on `safe` re-emits stdin to `stdout`.

`--pty` is available for wrapped commands in buffered mode when you need TTY-style formatting (for example `ls` columns/colors).

## How it works (`filter` subcommand)

1. `guardrails filter` executes a wrapped command (or reads piped stdin).
2. For wrapped commands, stdin is forwarded to the wrapped process while output remains buffered for filtering.
3. It invokes the checker and asks for sanitized output.
4. It forwards checker-provided filtered output.
5. If checker filtering fails (timeout/error/invalid response), it exits `43` and does not emit wrapped output.
6. It exits `42` when prompt injection/instruction redirection is detected.
7. Otherwise, it returns the wrapped command exit status (or `--exit-code` in stdin mode), even if trusted context caused benign output rewrites.

## Commands

```bash
# Wrap another CLI command
guardrails --checker codex -- gh issue list

# Wrap a GH command with guaranteed output from this repo
guardrails --checker codex -- gh release list --repo bbondy/guardrails --limit 5

# Same release command with JSON output
guardrails --checker codex -- gh release list --repo bbondy/guardrails --limit 5 --json tagName,name,isLatest,publishedAt

# Use Gemini as checker
guardrails --checker gemini -- gh issue list

# Use Cursor Agent as checker
guardrails --checker agent -- gh issue list

# Note: default Agent checker invocation is non-interactive:
# agent -f -p "<prompt>"

# Add a checker timeout (milliseconds)
guardrails --checker codex --checker-timeout-ms 10000 -- gh issue list

# Cap bytes sent to checker per stream (stdout/stderr)
guardrails --checker codex --max-output-bytes 262144 -- gh issue list

# Preserve TTY formatting while still buffering + checking output
guardrails --checker codex --pty -- ls

# Check arbitrary buffered text from stdin and pass it through if safe
cat output.txt | guardrails --checker claude

# Filter a wrapped command instead of blocking
guardrails filter --checker codex -- gh issue list

# Filter piped stdin and pass through unchanged output with --exit-code when no filtering is needed
cat output.txt | guardrails filter --checker claude --exit-code 0

# Override executable path and pass provider-specific arguments
guardrails --checker codex --checker-cmd /usr/local/bin/codex --checker-arg exec --checker-arg --json --checker-arg - -- ls -la

# Add extra checker context and permissions hints to payload
guardrails filter --checker codex \
  --checker-context "repo contains internal-only docs" \
  --checker-permission "workspace-write" \
  -- gh issue list
```

## Live GH API safety demo

This repo includes a defensive canary file with instruction-like text so you can verify blocking behavior end-to-end with the GitHub API.

```bash
# Run the built-in demo helper (tests all installed checkers; expects guardrails + gh)
./examples/run-gh-api-canary-demo.sh

# Optional: run demo for only one checker
CHECKER=gemini ./examples/run-gh-api-canary-demo.sh

# Or run directly
guardrails --checker codex -- \
  gh api repos/bbondy/guardrails/contents/examples/gh-api-safety-canary.txt \
  -H "Accept: application/vnd.github.raw"
echo $?
```

Expected result: guardrails prints a blocked prompt-injection message and exits `42`.

Safe comparison example:

```bash
guardrails --checker codex -- \
  gh api repos/bbondy/guardrails/contents/examples/gh-api-safe.txt \
  -H "Accept: application/vnd.github.raw"
echo $?
```

Expected result: safe text is printed and exit code is `0`.

## Exit codes

- `42`: blocked due to detected prompt injection/instruction redirection
- `43`: checker tool failure
- `126`: wrapped command found but not executable/permission denied
- `127`: wrapped command not found
- otherwise: wrapped command exit code (or `--exit-code` in stdin mode)

Notes:
- `43` applies to both `check` and `filter` modes when checker execution/parsing fails.
- In `filter` mode, guardrails returns `42` only when prompt injection/instruction redirection is detected.
- `--pty` requires a wrapped command.
- In `--pty` mode, wrapped `stdout`/`stderr` are captured as one merged stream.

Checker protocol details are documented in [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).
