#!/usr/bin/env bash
# Build the Termux/Android 32-bit ARMv7 binary: 9router-go-android-armv7
#
# Why this target is a script of its own, outside `make cross`:
# Go's linker requires external linking for every android target except
# arm64 (internal/platform MustLinkExternal: android && goarch != arm64),
# so a CGO_ENABLED=0 build is impossible here — the toolchain refuses with
# "android/arm requires external (cgo) linking, but cgo is not enabled".
# This is the single documented exception to the repo's CGO-free rule
# (§4.F of AGENTS.md): no Go dependency gains a cgo requirement; only the
# final link uses the NDK clang, because the Go linker cannot do it alone.
# Every other release target, android/arm64 included, stays CGO_ENABLED=0.
#
# The NDK is located from, in order: $ANDROID_NDK_HOME, $ANDROID_NDK_ROOT,
# $ANDROID_HOME/ndk/<version>, $ANDROID_SDK_ROOT/ndk/<version>,
# ~/Android/Sdk/ndk/<version>, /usr/local/lib/android/sdk/ndk/<version>
# (the GitHub ubuntu runner image path). API 24 matches Termux's own
# minimum supported Android version.
set -euo pipefail
cd "$(dirname "$0")/.."

API="${ANDROID_API:-24}"
OUT="${OUT:-9router-go-android-armv7}"
VERSION="${VERSION:-$(cat VERSION 2>/dev/null || echo 1.0.0)}"

find_ndk() {
  local candidates=(
    "${ANDROID_NDK_HOME:-}"
    "${ANDROID_NDK_ROOT:-}"
  )
  local sdk roots=("${ANDROID_HOME:-}" "${ANDROID_SDK_ROOT:-}" "$HOME/Android/Sdk" "/usr/local/lib/android/sdk")
  for root in "${roots[@]}"; do
    [[ -n "$root" ]] || continue
    # Newest installed NDK under <sdk>/ndk/, if any.
    for d in "$root"/ndk/*/; do
      [[ -d "$d" ]] && candidates+=("${d%/}")
    done
  done
  local c
  for c in "${candidates[@]}"; do
    if [[ -n "$c" && -x "$c/toolchains/llvm/prebuilt/linux-x86_64/bin/armv7a-linux-androideabi${API}-clang" ]]; then
      printf '%s\n' "$c"
      return 0
    fi
    if [[ -n "$c" && -x "$c/toolchains/llvm/prebuilt/darwin-x86_64/bin/armv7a-linux-androideabi${API}-clang" ]]; then
      printf '%s\n' "$c"
      return 0
    fi
  done
  return 1
}

NDK="$(find_ndk || true)"
if [[ -z "${NDK}" ]]; then
  cat >&2 <<'EOF'
error: Android NDK not found — the android/armv7 build needs its clang for
external linking (Go cannot internal-link android/arm).

Install it one of these ways:
  - Android Studio SDK Manager ("NDK (Side by side)"), then set
    ANDROID_NDK_HOME to the installed directory, or
  - sdkmanager "ndk;27.2.12479018", or
  - in Termux itself:  pkg install golang clang
    and build natively instead (GOOS=android GOARCH=arm GOARM=7 just works
    there, Termux's clang is the external linker).
EOF
  exit 1
fi

HOST_TAG="linux-x86_64"
[[ -x "$NDK/toolchains/llvm/prebuilt/$HOST_TAG/bin/armv7a-linux-androideabi${API}-clang" ]] || HOST_TAG="darwin-x86_64"
TOOLCHAIN="$NDK/toolchains/llvm/prebuilt/$HOST_TAG/bin"

echo "==> building $OUT (android/arm, GOARM=7, API $API, NDK $NDK)"
CGO_ENABLED=1 \
GOOS=android GOARCH=arm GOARM=7 \
CC="$TOOLCHAIN/armv7a-linux-androideabi${API}-clang" \
CXX="$TOOLCHAIN/armv7a-linux-androideabi${API}-clang++" \
go build -ldflags="-s -w -X 9router/proxy/internal/updater.CurrentVersion=${VERSION}" \
  -o "$OUT" ./cmd/9router-go/
echo "==> ./$OUT"
