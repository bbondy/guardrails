# Development, CI, and Releases

## Local development commands

```bash
cargo build --release
cargo fmt
cargo test
make install-hooks
```

`make install-hooks` configures git to use repo-managed hooks in `.githooks/`.

## Git hooks

Install once per clone:

```bash
make install-hooks
```

Installed hooks:

- `pre-commit` runs `cargo fmt --all -- --check`
- `pre-push` runs `cargo fmt --all -- --check` and `cargo test --locked`

Manual equivalent commands:

```bash
cargo fmt --all -- --check
cargo test --locked
```

If formatting or tests fail, `git push` is blocked.
GitHub CI enforces the same checks on pull requests and pushes to `main`.

## CI and releases

GitHub Actions is configured in `.github/workflows/ci.yml` to run:

- `cargo fmt --all -- --check`
- `cargo test --locked`
- cross-build artifacts for Linux/macOS/Windows (x64 + arm64)
- SHA256 files for each built binary and a combined `SHA256SUMS` manifest

On tags matching `v*`, the workflow publishes those artifacts to a GitHub Release.
On tag releases, it also publishes `@brianbondy/guardrails` to npmjs.com.

Required GitHub secrets for release publishing:

- `APPLE_CERT_P12`
- `APPLE_CERT_PASSWORD`
- `APPLE_ID`
- `APPLE_TEAM_ID`
- `APPLE_APP_SPECIFIC_PASSWORD`
- `NPM_TOKEN` (npm automation token with publish permission for `@brianbondy`)

Create a release by pushing a version tag:

```bash
make release
```

`make release` reads `version` from `Cargo.toml`, creates tag `v<version>`, and pushes it.
It requires a clean working tree and fails if the tag already exists.
It does not edit or commit `Cargo.toml`.
The release workflow then publishes binaries/checksums and updates/publishes the npm package with the same tag version.

To bump project version before releasing:

```bash
make bump-version BUMP=bugfix   # patch bump (x.y.z -> x.y.z+1)
make bump-version BUMP=minor    # minor bump (x.y.z -> x.y+1.0)
make bump-version BUMP=major    # major bump (x.y.z -> x+1.0.0)
```

This updates `Cargo.toml`, `Cargo.lock`, `package.json`, and `package-lock.json`. It does not commit or tag automatically.

For local npm publishing (outside GitHub Actions):

```bash
make publish
```

`make publish` requires `NPM_TOKEN` in your environment (for example via `direnv`) and publishes `@brianbondy/guardrails` using the current `Cargo.toml` version.

## Cross-platform build commands

```bash
# macOS arm64 (Apple Silicon)
make darwin-arm64
./dist/guardrails-darwin-arm64 --help

# macOS x64 (Intel)
make darwin-amd64
./dist/guardrails-darwin-amd64 --help

# Linux x64
make linux-amd64
./dist/guardrails-linux-amd64 --help

# Linux arm64
make linux-arm64
./dist/guardrails-linux-arm64 --help

# Windows x64
make windows-amd64
./dist/guardrails-windows-amd64.exe --help

# Windows arm64
make windows-arm64
./dist/guardrails-windows-arm64.exe --help

# Build all supported cross targets
make all-platforms
```
