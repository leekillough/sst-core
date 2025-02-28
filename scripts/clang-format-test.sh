#!/bin/bash
# This script will run clang-format on directories in sst-core to test/verify format
# shellcheck enable=all
# shellcheck disable=2312,2250

set -o pipefail

# Check for running in the root dir of SST-Core
if [[ ! -f ./scripts/clang-format-test.sh ]]; then
    echo "ERROR: This script must be run from the top level root directory of SST-Core..."
    exit 1
fi >&2

usage() {
    echo
    echo "Usage: scripts/clang-format-test.sh [--format-exe <path_to_clang-format>]"
    exit 1
} >&2

parse_options() {
    CLANG_FORMAT_EXE=clang-format
    CLANG_FORMAT_ARG=(--dry-run)

    while :; do
        case $1 in
            --format-exe)
                if [[ -z "$2" ]]; then
                    echo "Error: --format-exe requires a path to a clang-format command." >&2
                    usage
                fi
                CLANG_FORMAT_EXE=$2
                shift
                ;;
            -i)
                CLANG_FORMAT_ARG+=("-i")
                ;;
            -*)
                usage
                ;;
            *)
                break
        esac
        shift
    done
}

find_clang_format() {
    if ! command -v "${CLANG_FORMAT_EXE}" >/dev/null; then
        echo "Error: Cannot find ${CLANG_FORMAT_EXE} command" >&2
        exit 1
    fi

    CLANG_FORMAT_VERSION=$("${CLANG_FORMAT_EXE}" --version | sed -E 's/^[^0-9]*([0-9]+).*/\1/')
    if [[ ${CLANG_FORMAT_VERSION} != 12 ]]; then
        echo "clang-format version is ${CLANG_FORMAT_VERSION}. We require version 12."
        exit 1
    fi

    echo "Using ${CLANG_FORMAT_EXE} with arguments ${CLANG_FORMAT_ARG[*]}."
}

setup_dirs_to_skip() {
    # Setup SST-Core Directories to be skipped for clang-format checks
    DIRS_TO_SKIP=(./build)
    DIRS_TO_SKIP+=(./src/sst/core/libltdl)
    DIRS_TO_SKIP+=(./external)
    # Add additional directories to skip here...

    # Setup find command argument for directories to be skipped
    FIND_DIRS_TO_SKIP=("(")
    local DELIM=()
    for dir in "${DIRS_TO_SKIP[@]}"; do
        FIND_DIRS_TO_SKIP+=("${DELIM[@]}" -path "${dir}")
        DELIM=("-o")
    done
    FIND_DIRS_TO_SKIP+=(")")
}

clang_format_testing() {
    local ext=$1
    echo
    find . -type d "${FIND_DIRS_TO_SKIP[@]}" -prune -false -o -name "*.${ext}" -exec "${CLANG_FORMAT_EXE}" "${CLANG_FORMAT_ARG[@]}" {} \; > "clang_format_results_${ext}.txt" 2>&1
    echo "=== CLANG-FORMAT FINISHED *.${ext} CHECKS WITH RTN CODE $?"
}

evaluate_clang_format_testing() {
    local ext=$1
    echo
    if [[ -s "./clang_format_results_${ext}.txt" ]]; then
        echo "=== CLANG FORMAT RESULT FILE FOR .${ext} FILES IS NOT EMPTY - FAILURE"
        cat "./clang_format_results_${ext}.txt"
        FINAL_TEST_RESULT=1
    else
        echo "=== CLANG FORMAT RESULT FILE FOR .${ext} FILES IS EMPTY - SUCCESS"
    fi
}

run_tests() {
    cat<<EOF
=======================================
=== PERFORMING CLANG-FORMAT TESTING ===
=======================================
EOF
    FINAL_TEST_RESULT=0

    # Run clang-format on all .h and .cc files
    clang_format_testing h
    clang_format_testing cc

    # Evaluate the Results
    evaluate_clang_format_testing h
    evaluate_clang_format_testing cc

    # Display the final results
    cat<<EOF

========================================
=== FINAL TEST RESULT = (${FINAL_TEST_RESULT}) - $([[ ${FINAL_TEST_RESULT} -eq 0 ]] && echo PASSED || echo FAILED) ===
========================================

EOF
    return "${FINAL_TEST_RESULT}"
}

# Main program

parse_options "$@"
find_clang_format
setup_dirs_to_skip
run_tests
