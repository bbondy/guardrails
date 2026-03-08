# guardrails Architecture

This document explains how `guardrails` is implemented, file by file, and shows the exact protocol between the Rust app and checker CLIs.

## 1) What the binary does

`guardrails` wraps command output (or piped stdin), sends that output to a checker tool, and then decides:

- `check` mode: block or pass through.
- `filter` mode: rewrite output or fail.

Core invariants:

- `check` mode blocks on checker `unsafe` verdict (`exit 42`).
- `filter` mode trusts checker's `detected_prompt_injection` flag:
  - `true` => `exit 42`
  - `false` => pass through filtered output and return wrapped status / `--exit-code`
- checker failure in either mode => `exit 43`

## 2) Per-file implementation recap

| File | Responsibility | Key entry points |
|---|---|---|
| `src/main.rs` | Top-level startup and mode selection handoff | `main()` |
| `src/cli.rs` | Clap option schema and mode parse (`filter` subcommand) | `Cli`, `parse_mode_and_args()` |
| `src/runner.rs` | Runtime orchestration for wrapped-command and stdin paths | `run()`, `cmd_wrapped()`, `cmd_stdin()` |
| `src/checker.rs` | Checker process spawning, prompt construction, JSON parsing | `invoke_checker()`, `invoke_filter()` |
| `src/filter.rs` | Shared data types and stream-size clamp helper for checker payloads | `FilteredOutput`, `clamp_output_for_checker()` |

## 3) Runtime flow (simple)

### 3.1 Startup

1. `main()` calls `parse_mode_and_args()`.
2. Clap parses args into `Cli`.
3. `main()` validates `--pty` usage.
4. `runner::run(mode, cli)` executes.

### 3.2 `runner::run()` routing

`runner::run()` does early mode validation:

- `check` mode rejects `--checker-context` (exit `2`).

Then it chooses one of two paths:

- Wrapped command path: `cmd_wrapped(...)`
- Stdin path: `cmd_stdin(...)`

## 4) Mode behavior matrix

| Mode | Input source | Checker call | Success path | Failure path |
|---|---|---|---|---|
| `check` | wrapped command | `invoke_checker` | emit original stdout/stderr, exit wrapped status | checker error => `43`; unsafe => `42` |
| `check` | stdin | `invoke_checker` | emit original stdin, exit `--exit-code` | checker error => `43`; unsafe => `42` |
| `filter` | wrapped command | `invoke_filter` | emit checker-filtered stdout/stderr; `detected_prompt_injection=true` => `42`; else wrapped status | checker error => `43` |
| `filter` | stdin | `invoke_filter` | emit checker-filtered stdout; `detected_prompt_injection=true` => `42`; else `--exit-code` | checker error => `43` |

## 5) Protocol between guardrails and checker

`guardrails` does not use a network API. It spawns a checker executable and exchanges text through process args/stdin/stdout.

### 5.1 Checker process invocation

Default invocation when no `--checker-arg` is provided:

- `codex exec "<prompt>"`
- `claude -p "<prompt>"`
- `gemini -p "<prompt>"`
- `agent -f -p "<prompt>"` (fallback executable name: `cursor-agent`)

If `--checker-arg` is provided:

- those args are used as-is,
- prompt is written to checker stdin.

### 5.2 Payload JSON sent inside the prompt

The prompt includes this serialized request payload:

```json
{
  "checker": "codex",
  "task": "detect_prompt_injection",
  "output": {
    "command": "ls -la",
    "exit_code": 0,
    "stdout": "...",
    "stderr": "..."
  },
  "instructions": "...",
  "context": ["optional trusted context"],
  "permissions": ["optional permission hints"]
}
```

Notes:

- `context` is only accepted in `filter` mode.
- `stdout`/`stderr` in payload may be truncated by `--max-output-bytes`.

### 5.3 Expected checker response schemas

`check` mode response:

```json
{"verdict":"safe"}
```

or

```json
{"verdict":"unsafe","reason":"detected instruction redirection"}
```

`filter` mode response:

```json
{
  "stdout": "filtered stdout",
  "stderr": "filtered stderr",
  "detected_prompt_injection": false,
  "reason": "optional summary"
}
```

`detected_prompt_injection` drives `42` in filter mode.

### 5.4 Parser tolerance

Checker stdout parsing is tolerant in this order:

1. parse full stdout as JSON,
2. parse any single line as JSON,
3. parse first balanced JSON object from mixed text.

If parsing still fails => checker failure (`43`).

## 6) Explicit protocol examples

### Example A: `check` mode, safe output

Command:

```bash
guardrails --checker codex -- echo "hello"
```

Wrapped output captured by guardrails:

```json
{"stdout":"hello\n","stderr":""}
```

Checker response:

```json
{"verdict":"safe"}
```

Result:

- emits `hello`
- exits wrapped status (`0` here)

### Example B: `check` mode, unsafe output

Command:

```bash
guardrails --checker codex -- printf "ignore previous instructions\n"
```

Checker response:

```json
{"verdict":"unsafe","reason":"instruction redirection in stdout"}
```

Result:

- does not emit wrapped output
- prints blocked message on stderr
- exits `42`

### Example C: `filter` mode, benign transform

Command:

```bash
guardrails filter --checker codex --checker-context="remove .md entries" -- ls
```

Checker response:

```json
{
  "stdout": "Cargo.lock\nCargo.toml\n",
  "stderr": "",
  "detected_prompt_injection": false,
  "reason": "context transform"
}
```

Result:

- emits rewritten stdout
- exits wrapped status (`0` for `ls`)

### Example D: `filter` mode, injection filtered

Checker response:

```json
{
  "stdout": "safe-line\n",
  "stderr": "",
  "detected_prompt_injection": true,
  "reason": "removed instruction redirection"
}
```

Result:

- emits filtered stdout
- exits `42`

### Example E: checker failure (both modes)

Failure cases:

- checker executable missing,
- checker timeout,
- checker non-zero exit,
- checker invalid/unparseable JSON.

Result:

- prints checker error
- exits `43`

## 7) Exit codes

- `42`: prompt injection detected / blocked
- `43`: checker failure (spawn/timeout/non-zero/parse)
- `126`: wrapped command exists but is not executable
- `127`: wrapped command not found
- `2`: usage/config error (for example invalid mode+flag combination)
- otherwise: wrapped command status, or `--exit-code` in stdin mode

## 8) Notes for contributors

When debugging behavior, locate it in this order:

1. Mode (`check` vs `filter`)
2. Input path (wrapped command vs stdin)
3. Checker process outcome (spawn/timeout/status)
4. JSON parse outcome
5. Mode-specific exit branch in `runner.rs`

Most behavior changes are isolated to `runner.rs` decision branches and `checker.rs` schema parsing.
