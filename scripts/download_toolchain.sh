#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

CLANG_TAG="${CLANG_TAG:-20250912}"
CLANG_URL="${CLANG_URL:-https://github.com/liliumproject/clang/releases/download/${CLANG_TAG}/lilium_clang-${CLANG_TAG}.tar.gz}"

mkdir -p "$TOOLCHAIN_DIR"

if [ -z "${CLANG_BIN:-}" ] || [ ! -x "$CLANG_BIN/clang" ]; then
  echo "Downloading Lilium clang ${CLANG_TAG}"
  curl -L --fail --retry 3 --retry-delay 2 \
    -o "$TOOLCHAIN_DIR/lilium-clang.tar.gz" "$CLANG_URL"

  rm -rf "$TOOLCHAIN_DIR/lilium"
  mkdir -p "$TOOLCHAIN_DIR/lilium"
  tar -xf "$TOOLCHAIN_DIR/lilium-clang.tar.gz" -C "$TOOLCHAIN_DIR/lilium"

  CLANG_PATH="$(find "$TOOLCHAIN_DIR/lilium" \( -type f -o -type l \) -name clang 2>/dev/null | head -n1 || true)"
  [ -n "$CLANG_PATH" ] || { echo "Could not find clang in toolchain" >&2; exit 1; }
  CLANG_BIN="$(dirname "$CLANG_PATH")"
else
  echo "Using existing CLANG_BIN=$CLANG_BIN"
fi

echo "CLANG_BIN=$CLANG_BIN"
"$CLANG_BIN/clang" --version | head -n 2

if [ -n "${GITHUB_ENV:-}" ]; then
  echo "CLANG_BIN=$CLANG_BIN" >> "$GITHUB_ENV"
  echo "$CLANG_BIN" >> "$GITHUB_PATH"
fi
