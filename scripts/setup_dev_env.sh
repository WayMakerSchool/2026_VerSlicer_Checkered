#!/bin/bash
# Install host tools and local caches for VerSlicer iteration.
# Safe to re-run. Does not delete build trees or dependencies.

set -e
set -o pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "${ROOT}/scripts/lib/ccache_and_jobs.sh"

if command -v brew >/dev/null 2>&1; then
    brew install ccache ninja cmake
    if ! command -v clangd >/dev/null 2>&1 && [ ! -x /opt/homebrew/opt/llvm/bin/clangd ] && [ ! -x /usr/local/opt/llvm/bin/clangd ]; then
        brew install llvm
    fi
else
    echo "Homebrew is not installed. Install ccache, ninja, and cmake yourself." >&2
    exit 1
fi

enable_ccache_env || true

CCACHE_DIR_CONF="${HOME}/.ccache"
mkdir -p "${CCACHE_DIR_CONF}"
CONF="${CCACHE_DIR_CONF}/ccache.conf"
touch "${CONF}"

set_if_missing() {
    local key="$1"
    local value="$2"
    if grep -q "^${key} *=" "${CONF}"; then
        return 0
    fi
    echo "${key} = ${value}" >> "${CONF}"
    echo "ccache: set ${key} = ${value}"
}

set_if_missing max_size 50G
set_if_missing sloppiness "pch_defines,time_macros,include_file_mtime,include_file_ctime"
set_if_missing depend_mode true
set_if_missing inode_cache true

echo "ccache config: ${CONF}"
ccache -s || true

mkdir -p "${ROOT}/build"
mark_dirs_unindexed "${ROOT}/build" "${ROOT}/deps" "${ROOT}/deps/build"

if command -v tmutil >/dev/null 2>&1; then
    for excl in "${ROOT}/build" "${ROOT}/deps"; do
        if [ -d "${excl}" ]; then
            if tmutil addexclusion "${excl}"; then
                echo "Time Machine exclusion: ${excl}"
            else
                echo "Time Machine exclusion skipped for ${excl} (Full Disk Access required)." >&2
            fi
        fi
    done
fi

DEV_COMMANDS="${ROOT}/build/$(uname -m)-dev/compile_commands.json"
if [ -f "${DEV_COMMANDS}" ]; then
    ln -sfn "${DEV_COMMANDS}" "${ROOT}/compile_commands.json"
    echo "compile_commands.json -> ${DEV_COMMANDS}"
else
    echo "Configure the dev tree next: ./build_dev_macos.sh -C"
fi

LLVM_CLANGD=""
for candidate in /opt/homebrew/opt/llvm/bin/clangd /usr/local/opt/llvm/bin/clangd; do
    if [ -x "${candidate}" ]; then
        LLVM_CLANGD="${candidate}"
        break
    fi
done
if [ -n "${LLVM_CLANGD}" ]; then
    echo "clangd: ${LLVM_CLANGD}"
    echo "Point the editor's clangd path at that binary if it is not already on PATH."
fi

echo "Parallel jobs for this machine: $(macos_default_build_jobs)"
