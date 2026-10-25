#!/usr/bin/env bash
# 9router-go single-line installer: detects OS/arch, downloads the latest
# release binary from GitHub, installs it, and prints next steps.
#
#   curl -fsSL https://raw.githubusercontent.com/luqman-v1/9router-go/main/install.sh | bash
#
# Env overrides: VERSION (e.g. v1.9.2, default: latest), BINDIR (default:
# /usr/local/bin, falls back to ~/.local/bin).
set -euo pipefail

REPO="${REPO:-luqman-v1/9router-go}"
VERSION="${VERSION:-latest}"
BINDIR="${BINDIR:-/usr/local/bin}"

info()  { printf '\033[1;32m[9router-go]\033[0m %s\n' "$*"; }
warn()  { printf '\033[1;33m[9router-go]\033[0m %s\n' "$*" >&2; }
fatal() { printf '\033[1;31m[9router-go]\033[0m %s\n' "$*" >&2; exit 1; }

OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
ARCH="$(uname -m)"

# Termux (Android) has no /usr/local/bin and no sudo; its prefix is the whole
# installation root. Detect it before the generic Linux path: uname still
# says Linux there, so without this the installer picked the glibc-style
# linux asset and a directory that does not exist.
TERMUX=0
if [ -n "${TERMUX_VERSION:-}" ] || [ -n "${TERMUX_API:-}" ]; then
  TERMUX=1
fi
case "${PREFIX:-}" in
  *com.termux*) TERMUX=1 ;;
esac
if [ "$(uname -o 2>/dev/null || true)" = "Android" ]; then
  TERMUX=1
fi
if [ "$TERMUX" = "1" ]; then
  OS="android"
  # Only the untouched default is replaced: an explicit BINDIR wins.
  if [ "$BINDIR" = "/usr/local/bin" ]; then
    BINDIR="${PREFIX:-$HOME/../usr}/bin"
  fi
fi

case "$OS" in
  linux|darwin|android) ;;
  *) fatal "unsupported OS: $OS (Linux, macOS and Android/Termux only; Windows: download the .exe from https://github.com/$REPO/releases/latest)" ;;
esac
case "$ARCH" in
  x86_64|amd64) ARCH="amd64" ;;
  arm64|aarch64) ARCH="arm64" ;;
  armv7l|armv8l|arm) ARCH="armv7" ;;
  *) fatal "unsupported architecture: $ARCH (amd64/arm64/armv7 only)" ;;
esac
if [ "$ARCH" = "armv7" ] && [ "$OS" != "android" ]; then
  fatal "the armv7 build targets Android/Termux only — no $OS/armv7 asset is published"
fi
if [ "$ARCH" = "amd64" ] && [ "$OS" = "android" ]; then
  fatal "no Android x86_64 asset is published (arm64/armv7 only)"
fi

ASSET="9router-go-${OS}-${ARCH}"
if [ "$VERSION" = "latest" ]; then
  URL="https://github.com/${REPO}/releases/latest/download/${ASSET}"
else
  URL="https://github.com/${REPO}/releases/download/${VERSION}/${ASSET}"
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
info "downloading $URL ..."
curl -fsSL --retry 3 -o "$TMP/9router-go" "$URL" \
  || fatal "download failed — check https://github.com/$REPO/releases"
chmod +x "$TMP/9router-go"

if [ -w "$BINDIR" ]; then
  mv "$TMP/9router-go" "$BINDIR/9router-go"
else
  warn "$BINDIR not writable, trying sudo (or set BINDIR=\$HOME/.local/bin)"
  sudo mv "$TMP/9router-go" "$BINDIR/9router-go"
fi
trap - EXIT

info "installed to $BINDIR/9router-go"
"$BINDIR/9router-go" version || true
echo
info "start it with:"
echo "       9router-go"
echo "Dashboard: http://localhost:20130 (defaults: port 20130, data ~/.9router)"
