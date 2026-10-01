#!/bin/bash
# Single-config Debug tree for day-to-day work.
# Release packaging stays on ./build_release_macos.sh and build/<arch>/.
#
#   ./build_dev_macos.sh                 # configure if needed, build verslicer
#   ./build_dev_macos.sh -C              # configure only
#   ./build_dev_macos.sh -b              # build without reconfiguring
#   ./build_dev_macos.sh -t ollama_pipeline_test
#   ./build_dev_macos.sh -j 8
#
# Output: build/<arch>-dev/src/verslicer.app
# compile_commands.json in the repo root points at this tree.

set -e
set -o pipefail

_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${_SCRIPT_DIR}/scripts/lib/ccache_and_jobs.sh"
enable_ccache_env || true

CONFIGURE=1
BUILD=1
ARCH="$(uname -m)"
TARGET="OrcaSlicer"
OSX_DEPLOYMENT_TARGET="${OSX_DEPLOYMENT_TARGET:-11.3}"

while getopts ":Cbj:a:t:h" opt; do
    case "${opt}" in
        C) BUILD=0 ;;
        b) CONFIGURE=0 ;;
        j) export CMAKE_BUILD_PARALLEL_LEVEL="$OPTARG" ;;
        a) ARCH="$OPTARG" ;;
        t) TARGET="$OPTARG" ;;
        h)
            sed -n '2,12p' "$0" | sed 's/^# \?//'
            exit 0
            ;;
        *)
            echo "Unknown option: -${OPTARG}" >&2
            exit 1
            ;;
    esac
done

if [ -z "${CMAKE_BUILD_PARALLEL_LEVEL:-}" ]; then
    export CMAKE_BUILD_PARALLEL_LEVEL="$(macos_default_build_jobs)"
fi

PROJECT_DIR="${_SCRIPT_DIR}"
BUILD_DIR="${PROJECT_DIR}/build/${ARCH}-dev"
DEPS_BUILD_DIR="${PROJECT_DIR}/deps/build/${ARCH}"
DEPS_PREFIX="${DEPS_BUILD_DIR}/OrcaSlicer_dep/usr/local"

if [ ! -d "${DEPS_PREFIX}" ]; then
    echo "Dependencies not found: ${DEPS_PREFIX}" >&2
    echo "Build them once with ./build_release_macos.sh -d -x" >&2
    exit 1
fi

CMAKE_VERSION="$(cmake --version | head -1 | sed 's/[^0-9]*\([0-9]*\).*/\1/')"
CMAKE_POLICY_COMPAT=()
if [ "${CMAKE_VERSION}" -ge 4 ] 2>/dev/null; then
    export CMAKE_POLICY_VERSION_MINIMUM=3.5
    CMAKE_POLICY_COMPAT=(-DCMAKE_POLICY_VERSION_MINIMUM=3.5)
fi


LZMA_CMAKE_ARGS=()
if command -v brew >/dev/null 2>&1; then
    XZ_PREFIX="$(brew --prefix xz 2>/dev/null || true)"
    SDK_PATH="$(xcrun --show-sdk-path 2>/dev/null || true)"
    if [ -n "${XZ_PREFIX}" ] && [ -f "${XZ_PREFIX}/include/lzma.h" ] && [ -n "${SDK_PATH}" ] && [ ! -f "${SDK_PATH}/usr/include/lzma.h" ]; then
        # macOS ships liblzma but not lzma.h. Use Homebrew headers and the SDK library
        # so the app does not link /opt/homebrew/lib/liblzma.dylib.
        LZMA_CMAKE_ARGS=(
            -DLIBLZMA_INCLUDE_DIR="${XZ_PREFIX}/include"
            -DLIBLZMA_LIBRARY="${SDK_PATH}/usr/lib/liblzma.tbd"
        )
    fi
fi

CCACHE_ARGS=()
if command -v ccache >/dev/null 2>&1; then
    CCACHE_ARGS=(
        -DCMAKE_C_COMPILER_LAUNCHER=ccache
        -DCMAKE_CXX_COMPILER_LAUNCHER=ccache
    )
    echo "ccache: $(command -v ccache)"
else
    echo "ccache not found; install it with ./scripts/setup_dev_env.sh" >&2
fi

echo "Dev build:"
echo " - BUILD_DIR: ${BUILD_DIR}"
echo " - DEPS: ${DEPS_PREFIX}"
echo " - JOBS: ${CMAKE_BUILD_PARALLEL_LEVEL}"
echo " - TARGET: ${TARGET}"

mkdir -p "${BUILD_DIR}"
mark_dirs_unindexed "${PROJECT_DIR}/build" "${PROJECT_DIR}/deps" "${DEPS_BUILD_DIR}" "${BUILD_DIR}"

if [ "${CONFIGURE}" -eq 1 ]; then
    cmake_args=(
        -G Ninja
        -DCMAKE_BUILD_TYPE=Debug
        -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
        -DSLIC3R_DEV_FAST=ON
        -DORCA_TOOLS=ON
        -DSLIC3R_PCH=ON
        -DSLIC3R_ASAN=OFF
        -DSLIC3R_PROFILE=OFF
        -DCMAKE_OSX_ARCHITECTURES="${ARCH}"
        -DCMAKE_OSX_DEPLOYMENT_TARGET="${OSX_DEPLOYMENT_TARGET}"
        -DDEP_BUILD_DIR="${DEPS_BUILD_DIR}"
        -DCMAKE_PREFIX_PATH="${DEPS_PREFIX}"
        -DCMAKE_IGNORE_PREFIX_PATH="/opt/local;/usr/local;/opt/homebrew"
    )
    if [ "${#CMAKE_POLICY_COMPAT[@]}" -gt 0 ]; then
        cmake_args+=("${CMAKE_POLICY_COMPAT[@]}")
    fi
    if [ "${#CCACHE_ARGS[@]}" -gt 0 ]; then
        cmake_args+=("${CCACHE_ARGS[@]}")
    fi
    if [ "${#LZMA_CMAKE_ARGS[@]}" -gt 0 ]; then
        cmake_args+=("${LZMA_CMAKE_ARGS[@]}")
    fi
    cmake -S "${PROJECT_DIR}" -B "${BUILD_DIR}" "${cmake_args[@]}"
    ln -sfn "${BUILD_DIR}/compile_commands.json" "${PROJECT_DIR}/compile_commands.json"
fi

if [ "${BUILD}" -eq 1 ]; then
    if [ ! -f "${BUILD_DIR}/build.ninja" ]; then
        echo "Dev tree is not configured. Run ./build_dev_macos.sh -C" >&2
        exit 1
    fi
    cmake --build "${BUILD_DIR}" --target "${TARGET}" -j "${CMAKE_BUILD_PARALLEL_LEVEL}"
    echo "Built ${TARGET} -> ${BUILD_DIR}/src/verslicer.app"
fi
