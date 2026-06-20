#!/usr/bin/env bats
#
# T3: Git identity management tests for git-account
#
# Verifies that `add`/`add-work` create a per-account gitconfig
# (~/.git-account/<name>.gitconfig), add an [includeIf "gitdir:..."]
# entry with an ABSOLUTE path to ~/.gitconfig, and record the account
# metadata in ~/.git-account/accounts.txt.

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

@test "add creates ~/.git-account/<name>.gitconfig with user.name and user.email" {
    run git-account add personal personal@gmail.com \
        /home/corazon/projects/private/personal github.com
    [ "$status" -eq 0 ]

    local identity_file="${HOME}/.git-account/personal.gitconfig"
    [ -f "${identity_file}" ]

    run cat "${identity_file}"
    [[ "$output" == *"[user]"* ]]
    [[ "$output" == *"name = personal"* ]]
    [[ "$output" == *"email = personal@gmail.com"* ]]
}

@test "add adds an includeIf entry with an ABSOLUTE gitdir path to ~/.gitconfig" {
    run git-account add personal personal@gmail.com \
        /home/corazon/projects/private/personal github.com
    [ "$status" -eq 0 ]

    [ -f "${HOME}/.gitconfig" ]

    run cat "${HOME}/.gitconfig"
    # Absolute path with trailing slash, matching the doc example.
    [[ "$output" == *'[includeIf "gitdir:/home/corazon/projects/private/personal/"]'* ]]
    [[ "$output" == *"path = ${HOME}/.git-account/personal.gitconfig"* ]]

    # Must NOT contain a relative gitdir path.
    [[ "$output" != *"gitdir:personal"* ]]
    [[ "$output" != *"gitdir:projects"* ]]
}

@test "add records account metadata in ~/.git-account/accounts.txt with absolute key_path" {
    run git-account add personal personal@gmail.com \
        /home/corazon/projects/private/personal github.com
    [ "$status" -eq 0 ]

    local accounts_file="${HOME}/.git-account/accounts.txt"
    [ -f "${accounts_file}" ]

    # Exactly one line.
    local line_count
    line_count="$(wc -l < "${accounts_file}")"
    [ "$line_count" -eq 1 ]

    run cat "${accounts_file}"
    # Format: name|email|project_path|domain|key_path
    [ "${lines[0]}" = "personal|personal@gmail.com|/home/corazon/projects/private/personal|github.com|${HOME}/.ssh/id_ed25519_personal" ]
}

@test "add-work also creates identity, includeIf and metadata" {
    run git-account add-work github-work work@company.com \
        /home/corazon/projects/private/work github.com
    [ "$status" -eq 0 ]

    [ -f "${HOME}/.git-account/github-work.gitconfig" ]
    run cat "${HOME}/.git-account/github-work.gitconfig"
    [[ "$output" == *"name = github-work"* ]]
    [[ "$output" == *"email = work@company.com"* ]]

    run cat "${HOME}/.gitconfig"
    [[ "$output" == *'[includeIf "gitdir:/home/corazon/projects/private/work/"]'* ]]

    run cat "${HOME}/.git-account/accounts.txt"
    [ "${lines[0]}" = "github-work|work@company.com|/home/corazon/projects/private/work|github.com|${HOME}/.ssh/id_ed25519_github-work" ]
}

@test "re-adding an account does not duplicate includeIf or metadata" {
    git-account add personal personal@gmail.com \
        /home/corazon/projects/private/personal github.com >/dev/null

    local gitconfig_before accounts_before includeif_before
    gitconfig_before="$(cat "${HOME}/.gitconfig")"
    accounts_before="$(cat "${HOME}/.git-account/accounts.txt")"
    includeif_before="$(grep -c 'includeIf' "${HOME}/.gitconfig")"

    run git-account add personal personal@gmail.com \
        /home/corazon/projects/private/personal github.com
    [ "$status" -eq 0 ]

    # includeIf count unchanged.
    local includeif_after
    includeif_after="$(grep -c 'includeIf' "${HOME}/.gitconfig")"
    [ "$includeif_before" -eq "$includeif_after" ]

    # accounts.txt unchanged.
    [ "$accounts_before" == "$(cat "${HOME}/.git-account/accounts.txt")" ]
}
