# Shared helpers for macOS app and dev build scripts.
# shellcheck shell=bash

# Cap clang parallelism by RAM. Each PCH job is roughly 2.5 GB.
macos_default_build_jobs() {
    local ncpu ram_bytes ram_gb by_ram
    ncpu="$(sysctl -n hw.ncpu 2>/dev/null || echo 4)"
    ram_bytes="$(sysctl -n hw.memsize 2>/dev/null || echo 17179869184)"
    ram_gb="$((ram_bytes / 1024 / 1024 / 1024))"
    by_ram="$((ram_gb * 10 / 25))"
    if [ "${by_ram}" -lt 1 ]; then
        by_ram=1
    fi
    if [ "${by_ram}" -gt "${ncpu}" ]; then
        by_ram="${ncpu}"
    fi
    echo "${by_ram}"
}

enable_ccache_env() {
    if ! command -v ccache >/dev/null 2>&1; then
        return 1
    fi
    export CMAKE_C_COMPILER_LAUNCHER="${CMAKE_C_COMPILER_LAUNCHER:-ccache}"
    export CMAKE_CXX_COMPILER_LAUNCHER="${CMAKE_CXX_COMPILER_LAUNCHER:-ccache}"
    export CCACHE_SLOPPINESS="${CCACHE_SLOPPINESS:-pch_defines,time_macros,include_file_mtime,include_file_ctime}"
    export CCACHE_DEPEND="${CCACHE_DEPEND:-true}"
    export CCACHE_INODECACHE="${CCACHE_INODECACHE:-true}"
    return 0
}

# Echo -D flags for a cmake configure line. Empty when ccache is absent.
ccache_cmake_args() {
    if command -v ccache >/dev/null 2>&1; then
        printf '%s %s' \
            "-DCMAKE_C_COMPILER_LAUNCHER=${CMAKE_C_COMPILER_LAUNCHER:-ccache}" \
            "-DCMAKE_CXX_COMPILER_LAUNCHER=${CMAKE_CXX_COMPILER_LAUNCHER:-ccache}"
    fi
}

mark_dirs_unindexed() {
    local d
    for d in "$@"; do
        if [ -d "${d}" ]; then
            touch "${d}/.metadata_never_index"
            if command -v tmutil >/dev/null 2>&1; then
                tmutil addexclusion "${d}" >/dev/null 2>&1 || true
            fi
        fi
    done
}
