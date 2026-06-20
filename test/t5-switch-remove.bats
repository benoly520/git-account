#!/usr/bin/env bats
#
# T5: Account switch & remove tests for git-account
#
# Verifies `switch` (repoints an account's includeIf to a new path and
# updates accounts.txt) and `remove` (deletes the identity file, the
# includeIf entry, and the accounts.txt line, while keeping SSH keys
# and ~/.ssh/config intact).

# Path to the git-account script under test.
SCRIPT_PATH="${BATS_TEST_DIRNAME}/../src/git-account"

# Create a temporary HOME and bin directory for isolation.
setup() {
    export TEST_HOME="$(mktemp -d)"
    export HOME="${TEST_HOME}"
    export TEST_BIN_DIR="${TEST_HOME}/bin"
    mkdir -p "${TEST_BIN_DIR}"
    export PATH="${TEST_BIN_DIR}:${PATH}"

    ln -sf "${SCRIPT_PATH}" "${TEST_BIN_DIR}/git-account"
}

# Clean up the temporary directory.
teardown() {
    if [[ -n "${TEST_HOME:-}" && -d "${TEST_HOME}" ]]; then
        rm -rf "${TEST_HOME}"
    fi
}

@test "switch repoints an account's includeIf to a new path and updates accounts.txt" {
    local old_path="/home/corazon/projects/private/personal"
    local new_path="/home/corazon/projects/private/new-path"

    git-account add personal personal@gmail.com \
        "${old_path}" github.com >/dev/null

    # Old path should have an includeIf entry before switching.
    grep -q '\[includeIf "gitdir:/home/corazon/projects/private/personal/"\]' "${HOME}/.gitconfig"

    run git-account switch personal "${new_path}"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Switched account 'personal'"* ]]

    # Old includeIf for the old path should be gone.
    run grep -c 'gitdir:/home/corazon/projects/private/personal/' "${HOME}/.gitconfig"
    [ "$output" == "0" ]

    # New includeIf for the new path should exist, pointing at the identity file.
    run cat "${HOME}/.gitconfig"
    [[ "$output" == *'[includeIf "gitdir:/home/corazon/projects/private/new-path/"]'* ]]
    [[ "$output" == *"path = ${HOME}/.git-account/personal.gitconfig"* ]]

    # accounts.txt should now carry the new path.
    run cat "${HOME}/.git-account/accounts.txt"
    [ "${lines[0]}" = "personal|personal@gmail.com|${new_path}|github.com|${HOME}/.ssh/id_ed25519_personal" ]

    # Identity file should be untouched (switch only changes path mapping).
    [ -f "${HOME}/.git-account/personal.gitconfig" ]
}

@test "switch removes a pre-existing includeIf for the target path before adding" {
    local path_a="/home/corazon/projects/private/personal"
    local path_b="/home/corazon/projects/private/new-path"

    git-account add personal personal@gmail.com \
        "${path_a}" github.com >/dev/null
    git-account add-work github-work work@company.com \
        "${path_b}" github.com >/dev/null

    # Both paths start with their own includeIf entries.
    grep -q "gitdir:${path_a}/" "${HOME}/.gitconfig"
    grep -q "gitdir:${path_b}/" "${HOME}/.gitconfig"

    # Switch personal to path_b, which already has an includeIf (for github-work).
    run git-account switch personal "${path_b}"
    [ "$status" -eq 0 ]

    run grep -c '\[includeIf "gitdir:'"${path_b}"/'"\]' "${HOME}/.gitconfig"
    # Exactly one includeIf entry for path_b now (the new one for personal).
    [ "$output" == "1" ]

    # That single entry must point at personal's identity file.
    run grep -A1 "gitdir:${path_b}/" "${HOME}/.gitconfig"
    [[ "$output" == *"path = ${HOME}/.git-account/personal.gitconfig"* ]]
}

@test "switch on a non-existent account fails" {
    run git-account switch nope /home/corazon/projects/private/whatever
    [ "$status" -ne 0 ]
    [[ "$output" == *"account 'nope' not found"* ]]
}

@test "remove deletes identity file, includeIf entry, and accounts.txt line" {
    local path="/home/corazon/projects/private/personal"

    git-account add personal personal@gmail.com \
        "${path}" github.com >/dev/null
    git-account add-work github-work work@company.com \
        /home/corazon/projects/private/work github.com >/dev/null

    [ -f "${HOME}/.git-account/personal.gitconfig" ]
    grep -q "gitdir:${path}/" "${HOME}/.gitconfig"
    grep -q "^personal|" "${HOME}/.git-account/accounts.txt"

    run git-account remove personal
    [ "$status" -eq 0 ]
    [[ "$output" == *"Deleted Git identity"* ]]
    [[ "$output" == *"Removed account 'personal'"* ]]
    [[ "$output" == *"SSH key and ~/.ssh/config left intact"* ]]

    # Identity file gone.
    [ ! -f "${HOME}/.git-account/personal.gitconfig" ]

    # includeIf entry for personal's path gone.
    run grep -c "gitdir:${path}/" "${HOME}/.gitconfig"
    [ "$output" == "0" ]

    # accounts.txt no longer has the personal line.
    run grep -c "^personal|" "${HOME}/.git-account/accounts.txt"
    [ "$output" == "0" ]

    # The other account remains untouched.
    grep -q "^github-work|" "${HOME}/.git-account/accounts.txt"
    [ -f "${HOME}/.git-account/github-work.gitconfig" ]
}

@test "remove does NOT delete SSH keys or ~/.ssh/config entries" {
    local path="/home/corazon/projects/private/personal"

    git-account add personal personal@gmail.com \
        "${path}" github.com >/dev/null

    local key="${HOME}/.ssh/id_ed25519_personal"
    [ -f "${key}" ]
    grep -q '^Host github.com$' "${HOME}/.ssh/config"

    git-account remove personal >/dev/null

    # SSH key and config entry must remain.
    [ -f "${key}" ]
    grep -q '^Host github.com$' "${HOME}/.ssh/config"
}

@test "remove on a non-existent account does not crash and reports nothing removed" {
    # No accounts at all yet.
    run git-account remove ghost
    [ "$status" -eq 0 ]
    [[ "$output" == *"Git identity not found"* ]]
    [[ "$output" == *"not found"* ]]
}
