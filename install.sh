#!/usr/bin/env sh
set -eu

REPO="bbondy/guardrails"
API_URL="https://api.github.com/repos/${REPO}/releases/latest"
INSTALL_DIR="${INSTALL_DIR:-/usr/local/bin}"
BIN_NAME="guardrails"

need_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "error: required command not found: $1" >&2
    exit 1
  fi
}

need_cmd curl
need_cmd mktemp
need_cmd chmod
need_cmd mv
need_cmd rm
need_cmd uname

OS="$(uname -s)"
ARCH="$(uname -m)"

case "$OS" in
  Darwin) OS_KEY="darwin" ;;
  Linux) OS_KEY="linux" ;;
  *)
    echo "error: unsupported OS: $OS" >&2
    exit 1
    ;;
esac

case "$ARCH" in
  arm64|aarch64) ARCH_KEY="arm64" ;;
  x86_64|amd64) ARCH_KEY="amd64" ;;
  *)
    echo "error: unsupported architecture: $ARCH" >&2
    exit 1
    ;;
esac

ASSET_NAME="${BIN_NAME}-${OS_KEY}-${ARCH_KEY}"
SHA_NAME="${ASSET_NAME}.sha256"

TAG="$(curl -fsSL "$API_URL" | sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1)"
if [ -z "$TAG" ]; then
  echo "error: unable to resolve latest release tag" >&2
  exit 1
fi

BASE_URL="https://github.com/${REPO}/releases/download/${TAG}"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

BIN_PATH="${TMP_DIR}/${ASSET_NAME}"
SHA_PATH="${TMP_DIR}/${SHA_NAME}"

echo "Downloading ${ASSET_NAME} from ${TAG}..."
curl -fsSL "${BASE_URL}/${ASSET_NAME}" -o "$BIN_PATH"
curl -fsSL "${BASE_URL}/${SHA_NAME}" -o "$SHA_PATH"

ACTUAL_SHA=""
if command -v shasum >/dev/null 2>&1; then
  ACTUAL_SHA="$(shasum -a 256 "$BIN_PATH" | awk '{print $1}')"
elif command -v sha256sum >/dev/null 2>&1; then
  ACTUAL_SHA="$(sha256sum "$BIN_PATH" | awk '{print $1}')"
else
  echo "error: need shasum or sha256sum to verify download" >&2
  exit 1
fi

EXPECTED_SHA="$(awk '{print $1}' "$SHA_PATH")"
if [ "$ACTUAL_SHA" != "$EXPECTED_SHA" ]; then
  echo "error: checksum mismatch for ${ASSET_NAME}" >&2
  echo "expected: $EXPECTED_SHA" >&2
  echo "actual:   $ACTUAL_SHA" >&2
  exit 1
fi

chmod +x "$BIN_PATH"

DEST_PATH="${INSTALL_DIR}/${BIN_NAME}"
if [ -w "$INSTALL_DIR" ]; then
  mv "$BIN_PATH" "$DEST_PATH"
else
  need_cmd sudo
  sudo mv "$BIN_PATH" "$DEST_PATH"
fi

echo "Installed ${BIN_NAME} to ${DEST_PATH}"
echo "Run: ${BIN_NAME} --help"
