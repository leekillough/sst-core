#!/bin/bash
# This script will run cmake-format on directories in sst-core to test/verify format
# shellcheck enable=all
# shellcheck disable=2312,2250

set -o pipefail

# Check for running in the root dir of SST-Core
if [[ ! -f ./scripts/cmake-format-test.sh  ]]; then
    echo "ERROR: This script must be run from the top level root directory of SST-Core..." >&2
    exit 1
fi

usage() {
    echo "Usage: scripts/cmake-format-test.sh [-i] [--format-exe <path_to_cmake-format>] [--lint-exe <path_to_cmake-lint>]" >&2
    exit 1
}

parse_options() {
    CMAKE_FORMAT_EXE="cmake-format"
    CMAKE_FORMAT_ARG=("--check")

    CMAKE_LINT_EXE="cmake-lint"
    CMAKE_LINT_ARG=("--suppress-decoration")

    while :; do
        case $1 in
            --format-exe)
                if [[ -z "$2" ]]; then
                    echo "Error: --format-exe requires a path to a cmake-format command." >&2
                    usage
                fi
                CMAKE_FORMAT_EXE=$2
                shift
                ;;
            --lint-exe)
                if [[ -z "$2" ]]; then
                    echo "Error: --lint-exe requires a path to a cmake-lint command." >&2
                    usage
                fi
                CMAKE_LINT_EXE=$2
                shift
                ;;
            -i)
                CMAKE_FORMAT_ARG+=("-i")
                ;;
            -*)
                usage ;;
            *)
                break
        esac
        shift
    done
}

find_cmake_format() {
    if ! command -v "${CMAKE_FORMAT_EXE}" >/dev/null; then
        echo "Cannot find ${CMAKE_FORMAT_EXE} command" >&2
        exit 1
    fi

    CMAKE_FORMAT_ARG+=("--config-files=./experimental/.cmake-format.yaml")
    CMAKE_FORMAT_OUTFILE="cmake_format_results.txt"
    CMAKE_CHECK_FILES=".cmake_format_files.txt"

    cat<<EOF
Using cmake-format '${CMAKE_FORMAT_EXE}' with arguments '${CMAKE_FORMAT_ARG[@]}'.
EOF
}

find_cmake_lint() {
    if ! command -v "${CMAKE_LINT_EXE}" >/dev/null; then
        echo "Cannot find ${CMAKE_LINT_EXE} command" >&2
        exit 1
    fi

    CMAKE_LINT_ARG+=("--config-files=./experimental/.cmake-format.yaml")
    CMAKE_LINT_OUTFILE="cmake_lint_results.txt"

    cat<<EOF
Using cmake-lint '${CMAKE_LINT_EXE}' with arguments '${CMAKE_LINT_ARG[@]}'.
EOF
}

setup_dirs_to_skip() {
    # Setup SST-Core Directories to be skipped for cmake-format checks
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

find_cmake_files() {
    cat<<EOF
============================
=== FINDING CMAKE FILES  ===
============================
EOF
    # So that our hard work can be reused.
    find . -type d "${FIND_DIRS_TO_SKIP[@]}" -prune -false -o -type f \( -name '*.cmake' -o -name 'CMakeLists.txt' \) -print0 | mapfile -d '' CMAKE_CHECK_FILES
    cat<<EOF
=== FIND FINISHED CHECKS WITH RTN CODE $?
EOF
}

cmake_format_testing() {
    cat <<EOF
=======================================
=== PERFORMING CMAKE-FORMAT TESTING ===
=======================================
EOF
    for file in "${CMAKE_CHECK_FILES[@]}"; do
        "${CMAKE_FORMAT_EXE}" "${CMAKE_FORMAT_ARG[@]}" "${file}"
        rtncode=$?
        [[ ${rtncode} -ne 0 ]] && break
    done > "${CMAKE_FORMAT_OUTFILE}" 2>&1

    cat <<EOF
=== CMAKE-FORMAT FINISHED CHECKS WITH RTN CODE ${rtncode}
EOF
}

cmake_lint_testing() {
    cat <<EOF
=====================================
=== PERFORMING CMAKE-LINT TESTING ===
=====================================
EOF
    for file in "${CMAKE_CHECK_FILES[@]}"; do
        "${CMAKE_LINT_EXE}" "${CMAKE_LINT_ARG[@]}" "${file}"
        rtncode=$?
        [[ ${rtncode} -ne 0 ]] && break
    done > "${CMAKE_LINT_OUTFILE}" 2>&1

    cat<<EOF
=== CMAKE-LINT FINISHED CHECKS WITH RTN CODE ${rtncode}
EOF
}

evaluate_cmake_format_testing() {
    echo
    if [[ -s ${CMAKE_FORMAT_OUTFILE} ]]; then
        echo "=== CMAKE FORMAT RESULT FILE IS NOT EMPTY - FAILURE"
        cat "${CMAKE_FORMAT_OUTFILE}"
        FINAL_TEST_RESULT=1
    else
        echo "=== CMAKE FORMAT RESULT FILE IS EMPTY - SUCCESS"
    fi
}

evaluate_cmake_lint_testing() {
    echo
    if [[ -s ${CMAKE_LINT_OUTFILE} ]]; then
        echo "=== CMAKE LINT RESULT FILE IS NOT EMPTY - FAILURE"
        cat "${CMAKE_LINT_OUTFILE}"
        FINAL_TEST_RESULT=1
    else
        echo "=== CMAKE LINT RESULT FILE IS EMPTY - SUCCESS"
    fi
}

run_tests() {
    # Set a test result return to a default rtn
    FINAL_TEST_RESULT=0

    cmake_format_testing
    cmake_lint_testing

    # Evaluate the Results
    evaluate_cmake_format_testing
    evaluate_cmake_lint_testing

    # Display the final results
    cat<<EOF

========================================
=== FINAL TEST RESULT = (${FINAL_TEST_RESULT}) - $([[ ${FINAL_TEST_RESULT} -eq 0 ]] && echo PASSED || echo FAILED) ==="
========================================

EOF
    return "${FINAL_TEST_RESULT}"
}

# Main program
parse_options "$@"
find_cmake_format
find_cmake_lint
setup_dirs_to_skip
find_cmake_files
run_tests
