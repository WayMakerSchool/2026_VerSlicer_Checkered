# Write git_commit_hash.h only when the hash string changes so dependents
# (not the precompiled header) rebuild.
if(NOT DEFINED OUT_FILE OR NOT DEFINED SOURCE_DIR)
    message(FATAL_ERROR "update_git_commit_hash.cmake requires OUT_FILE and SOURCE_DIR")
endif()

set(_hash "")
if(DEFINED ENV{git_commit_hash} AND NOT "$ENV{git_commit_hash}" STREQUAL "")
    string(SUBSTRING "$ENV{git_commit_hash}" 0 7 _hash)
elseif(DEFINED GIT_EXECUTABLE AND NOT "${GIT_EXECUTABLE}" STREQUAL "" AND NOT "${GIT_EXECUTABLE}" STREQUAL "GIT_EXECUTABLE-NOTFOUND" AND EXISTS "${SOURCE_DIR}/.git")
    execute_process(
        COMMAND "${GIT_EXECUTABLE}" log -1 --format=%h
        WORKING_DIRECTORY "${SOURCE_DIR}"
        OUTPUT_VARIABLE _hash
        OUTPUT_STRIP_TRAILING_WHITESPACE
        ERROR_QUIET
    )
endif()

if("${_hash}" STREQUAL "")
    set(_hash "0000000")
endif()

set(_content "#pragma once\n#define GIT_COMMIT_HASH \"${_hash}\"\n")
if(EXISTS "${OUT_FILE}")
    file(READ "${OUT_FILE}" _current)
else()
    set(_current "")
endif()

if(NOT "${_current}" STREQUAL "${_content}")
    file(WRITE "${OUT_FILE}" "${_content}")
endif()
