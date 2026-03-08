BINARY = guardrails
RELEASE_VERSION = $(shell sed -nE 's/^version[[:space:]]*=[[:space:]]*"([0-9]+\.[0-9]+\.[0-9]+)".*/\1/p' Cargo.toml | head -n 1)
RELEASE_TAG = v$(RELEASE_VERSION)

.PHONY: build
build:
	cargo build --release

.PHONY: install-hooks
install-hooks:
	@git config core.hooksPath .githooks
	@chmod +x .githooks/pre-commit .githooks/pre-push
	@echo "installed git hooks from .githooks"

.PHONY: demo
demo: build
	GUARDRAILS_BIN=./target/release/guardrails ./examples/run-gh-api-canary-demo.sh

.PHONY: release
release:
	@if [ -z "$(RELEASE_VERSION)" ]; then \
		echo "error: unable to read release version from Cargo.toml"; \
		exit 1; \
	fi
	@if ! git diff --quiet || ! git diff --cached --quiet; then \
		echo "error: working tree must be clean before release"; \
		exit 1; \
	fi
	@if git rev-parse -q --verify "refs/tags/$(RELEASE_TAG)" >/dev/null; then \
		echo "error: tag $(RELEASE_TAG) already exists"; \
		exit 1; \
	fi
	git tag "$(RELEASE_TAG)"
	git push origin "$(RELEASE_TAG)"
	@echo "pushed tag $(RELEASE_TAG)"
	@echo "GitHub Actions will publish release binaries/checksums and the npm package."
	@echo "watch with: gh run watch --repo bbondy/guardrails"

.PHONY: bump-version
bump-version:
	@if [ -z "$(BUMP)" ]; then \
		echo "error: BUMP is required (bugfix, minor, or major)"; \
		exit 1; \
	fi
	@if [ "$(BUMP)" != "bugfix" ] && [ "$(BUMP)" != "minor" ] && [ "$(BUMP)" != "major" ]; then \
		echo "error: BUMP must be one of: bugfix, minor, major"; \
		exit 1; \
	fi
	@set -eu; \
	current="$(RELEASE_VERSION)"; \
	if [ -z "$$current" ]; then \
		echo "error: unable to read version from Cargo.toml"; \
		exit 1; \
	fi; \
	major="$${current%%.*}"; \
	rest="$${current#*.}"; \
	minor="$${rest%%.*}"; \
	patch="$${rest#*.}"; \
	case "$(BUMP)" in \
		bugfix) patch="$$((patch + 1))" ;; \
		minor) minor="$$((minor + 1))"; patch=0 ;; \
		major) major="$$((major + 1))"; minor=0; patch=0 ;; \
	esac; \
	next="$$major.$$minor.$$patch"; \
	awk -v v="$$next" '\
		BEGIN { done = 0 } \
		!done && $$0 ~ /^version[[:space:]]*=[[:space:]]*"[0-9]+\.[0-9]+\.[0-9]+"/ { \
			print "version = \"" v "\""; \
			done = 1; \
			next; \
		} \
		{ print }' Cargo.toml > Cargo.toml.tmp; \
	mv Cargo.toml.tmp Cargo.toml; \
	cargo generate-lockfile >/dev/null; \
	if [ -f package.json ]; then \
		if ! command -v npm >/dev/null 2>&1; then \
			echo "error: npm is required to update package.json/package-lock.json"; \
			exit 1; \
		fi; \
		if ! command -v node >/dev/null 2>&1; then \
			echo "error: node is required to update package.json/package-lock.json"; \
			exit 1; \
		fi; \
		npm version --no-git-tag-version --allow-same-version "$$next" >/dev/null; \
		npm install --package-lock-only --ignore-scripts >/dev/null; \
	fi; \
	echo "bumped version: $$current -> $$next (Cargo.toml/Cargo.lock + package.json/package-lock.json)"

.PHONY: publish
publish:
	@if ! command -v npm >/dev/null 2>&1; then \
		echo "error: npm is required"; \
		exit 1; \
	fi
	@if ! command -v node >/dev/null 2>&1; then \
		echo "error: node is required"; \
		exit 1; \
	fi
	@if [ -z "$$NPM_TOKEN" ]; then \
		echo "error: NPM_TOKEN is required (export it in your shell, e.g. via direnv)"; \
		exit 1; \
	fi
	@set -eu; \
	version="$(RELEASE_VERSION)"; \
	if [ -z "$$version" ]; then \
		echo "error: unable to read package version from Cargo.toml"; \
		exit 1; \
	fi; \
	tmpdir="$$(mktemp -d)"; \
	cleanup() { rm -rf "$$tmpdir"; }; \
	trap cleanup EXIT; \
	cp package.json README.md "$$tmpdir"/; \
	cp -R npm "$$tmpdir"/npm; \
	printf '//registry.npmjs.org/:_authToken=%s\n' "$$NPM_TOKEN" > "$$tmpdir/.npmrc"; \
	PACKAGE_JSON_PATH="$$tmpdir/package.json" PACKAGE_VERSION="$$version" node -e '\
const fs = require("node:fs"); \
const p = process.env.PACKAGE_JSON_PATH; \
const v = process.env.PACKAGE_VERSION; \
const pkg = JSON.parse(fs.readFileSync(p, "utf8")); \
pkg.version = v; \
fs.writeFileSync(p, JSON.stringify(pkg, null, 2) + "\n");'; \
	otp_args=""; \
	if [ -n "$${NPM_OTP:-}" ]; then \
		otp_args="--otp=$$NPM_OTP"; \
	fi; \
	( cd "$$tmpdir" && npm publish --access public $$otp_args ); \
	echo "published @brianbondy/guardrails@$$version"

.PHONY: darwin-arm64
darwin-arm64:
	$(call docker-build-target,$@,aarch64-apple-darwin)

.PHONY: darwin-amd64
darwin-amd64:
	$(call docker-build-target,$@,x86_64-apple-darwin)

.PHONY: linux-amd64
linux-amd64:
	$(call docker-build-target,$@,x86_64-unknown-linux-gnu)

.PHONY: linux-arm64
linux-arm64:
	$(call docker-build-target,$@,aarch64-unknown-linux-gnu)

.PHONY: windows-amd64
windows-amd64:
	$(call docker-build-target,$@,x86_64-pc-windows-gnu)

.PHONY: windows-arm64
windows-arm64:
	$(call docker-build-target,$@,aarch64-pc-windows-gnullvm)

.PHONY: all-platforms
all-platforms: darwin-arm64 darwin-amd64 linux-amd64 linux-arm64 windows-amd64 windows-arm64

.PHONY: clean
clean:
	cargo clean
	rm -rf dist

define docker-build-target
	docker build -f Dockerfile.darwin -t $(BINARY)-$(1) \
	  --build-arg TARGET=$(2) .
	$(call docker-extract,$(BINARY)-$(1),$(1))
endef

define docker-extract
	mkdir -p dist
	docker rm -f tmp-$(BINARY) 2>/dev/null || true
	docker create --name tmp-$(BINARY) $(1) /dev/null
	docker cp tmp-$(BINARY):/$(BINARY) dist/$(call artifact-name,$(2))
	docker rm tmp-$(BINARY)
endef

define artifact-name
$(BINARY)-$(1)$(if $(findstring windows,$(1)),.exe,)
endef
