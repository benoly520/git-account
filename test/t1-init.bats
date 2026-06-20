#!/usr/bin/env bats
#
# T1: Project initialization tests for git-account
#
# Verifies that the git-account script framework supports
# --help / help / -h and --version / version / -v, and that
# running with no arguments defaults to showing help.

# Path to the git-account script under test.
SCRIPT_PATH="${BATS_TEST_DIRNAME}/../src/git-account"

# Create a temporary HOME and bin directory for isolation.
setup() {
    export TEST_HOME="$(mktemp -d)"
    export HOME="${TEST_HOME}"
    export TEST_BIN_DIR="${TEST_HOME}/bin"
    mkdir -p "${TEST_BIN_DIR}"
    export PATH="${TEST_BIN_DIR}:${PATH}"

    # Symlink the script into the test bin directory so it is on PATH.
    ln -sf "${SCRIPT_PATH}" "${TEST_BIN_DIR}/git-account"
}

# Clean up the temporary directory.
teardown() {
    if [[ -n "${TEST_HOME:-}" && -d "${TEST_HOME}" ]]; then
        rm -rf "${TEST_HOME}"
    fi
}

@test "git-account help displays the help message" {
    run git-account help
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "git-account - Manage multiple Git accounts easily" ]
    [[ "$output" == *"Usage:"* ]]
    [[ "$output" == *"git-account help"* ]]
}

@test "git-account --help displays the help message" {
    run git-account --help
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "git-account - Manage multiple Git accounts easily" ]
}

@test "git-account -h displays the help message" {
    run git-account -h
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "git-account - Manage multiple Git accounts easily" ]
}

@test "git-account version displays the version" {
    run git-account version
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "git-account version 0.1.0" ]
}

@test "git-account --version displays the version" {
    run git-account --version
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "git-account version 0.1.0" ]
}

@test "git-account -v displays the version" {
    run git-account -v
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "git-account version 0.1.0" ]
}

@test "git-account with no arguments defaults to showing help" {
    run git-account
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "git-account - Manage multiple Git accounts easily" ]
    [[ "$output" == *"Usage:"* ]]
}
