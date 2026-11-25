#!/usr/bin/env bash
# Shared paths and build environment. Source this from other scripts.

export DEVICE="${DEVICE:-lime}"
export WORKSPACE="${GITHUB_WORKSPACE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

export KERNEL_DIR="$WORKSPACE/kernel"
export AK_DIR="$WORKSPACE/AK3"
export EXTERNAL_DIR="$WORKSPACE/external"
export RTW88_DIR="$EXTERNAL_DIR/rtw88-android"
export TOOLCHAIN_DIR="$WORKSPACE/toolchain"
export OUT_DIR="$WORKSPACE/out"
export FIRMWARE_DIR="$WORKSPACE/firmware"
export STAGING_DIR="$WORKSPACE/staging"
export ARTIFACTS_DIR="$WORKSPACE/artifacts"

export ARCH=arm64
export SUBARCH=arm64
export LLVM=1
export LLVM_IAS=1
export CC=clang
export LD=ld.lld
export AR=llvm-ar
export NM=llvm-nm
export OBJCOPY=llvm-objcopy
export OBJDUMP=llvm-objdump
export STRIP=llvm-strip
export CROSS_COMPILE="${CROSS_COMPILE:-aarch64-linux-gnu-}"
export CROSS_COMPILE_ARM32="${CROSS_COMPILE_ARM32:-arm-linux-gnueabi-}"
export CLANG_TRIPLE="${CLANG_TRIPLE:-aarch64-linux-gnu-}"
export HOSTCC=gcc
export HOSTCXX=g++

export JOBS="${JOBS:-$(nproc)}"

if [ -n "${CLANG_BIN:-}" ] && [ -d "$CLANG_BIN" ]; then
  export PATH="$CLANG_BIN:$PATH"
fi

kmake() {
  make -C "$KERNEL_DIR" O="$OUT_DIR" \
    ARCH="$ARCH" SUBARCH="$SUBARCH" \
    LLVM="$LLVM" LLVM_IAS="$LLVM_IAS" \
    CC="$CC" LD="$LD" AR="$AR" NM="$NM" \
    OBJCOPY="$OBJCOPY" OBJDUMP="$OBJDUMP" STRIP="$STRIP" \
    CROSS_COMPILE="$CROSS_COMPILE" \
    CROSS_COMPILE_ARM32="$CROSS_COMPILE_ARM32" \
    CLANG_TRIPLE="$CLANG_TRIPLE" \
    HOSTCC="$HOSTCC" HOSTCXX="$HOSTCXX" \
    KBUILD_BUILD_USER="${KBUILD_BUILD_USER:-lilium}" \
    KBUILD_BUILD_HOST="${KBUILD_BUILD_HOST:-github-actions}" \
    "$@"
}
