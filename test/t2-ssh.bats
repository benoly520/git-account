#!/usr/bin/env bats
#
# T2: SSH key management tests for git-account
#
# Verifies that `add` and `add-work` generate ed25519 SSH keys and
# update ~/.ssh/config correctly, that re-adding an existing account
# skips key generation, and that the platform-aware HostName/Port
# resolution (SSH-over-443 for github.com/gitlab.com, standard SSH
# otherwise, with --port override) behaves as designed.

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

@test "add generates an ed25519 key and a Host=<domain> config entry" {
    run git-account add personal personal@gmail.com \
        /home/corazon/projects/private/personal github.com
    [ "$status" -eq 0 ]
    [[ "$output" == *"Generated SSH key"* ]]

    # Private and public keys should exist.
    [ -f "${HOME}/.ssh/id_ed25519_personal" ]
    [ -f "${HOME}/.ssh/id_ed25519_personal.pub" ]

    # Public key should be ed25519.
    run head -1 "${HOME}/.ssh/id_ed25519_personal.pub"
    [[ "$output" == ssh-ed25519* ]]

    # ~/.ssh/config should contain a Host github.com entry. github.com is a
    # known platform, so it defaults to SSH-over-443: HostName ssh.github.com
    # plus an explicit Port 443 directive.
    [ -f "${HOME}/.ssh/config" ]
    run cat "${HOME}/.ssh/config"
    [[ "$output" == *"Host github.com"* ]]
    [[ "$output" == *"HostName ssh.github.com"* ]]
    [[ "$output" == *"Port 443"* ]]
    [[ "$output" == *"IdentityFile ~/.ssh/id_ed25519_personal"* ]]
    # Must NOT fall back to the bare domain as HostName.
    [[ "$output" != *"HostName github.com"* ]]
}

@test "add-work generates a Host alias entry (Host=<name>) pointing to the resolved endpoint" {
    run git-account add-work github-work work@company.com \
        /home/corazon/projects/private/work github.com
    [ "$status" -eq 0 ]

    # Key named after the account.
    [ -f "${HOME}/.ssh/id_ed25519_github-work" ]

    # Config should use the alias as Host, with HostName = ssh.github.com
    # and Port 443 (github.com defaults to SSH-over-443).
    run cat "${HOME}/.ssh/config"
    [[ "$output" == *"Host github-work"* ]]
    [[ "$output" == *"HostName ssh.github.com"* ]]
    [[ "$output" == *"Port 443"* ]]
    [[ "$output" == *"IdentityFile ~/.ssh/id_ed25519_github-work"* ]]

    # The alias must be distinct from the raw domain entry.
    [[ "$output" != *"Host github.com"* ]]
}

@test "add --port 22 falls back to standard SSH (bare domain, no Port directive)" {
    run git-account add personal personal@gmail.com \
        /home/corazon/projects/private/personal github.com --port 22
    [ "$status" -eq 0 ]

    run cat "${HOME}/.ssh/config"
    [[ "$output" == *"Host github.com"* ]]
    [[ "$output" == *"HostName github.com"* ]]
    # No Port directive should be written for the SSH default port.
    [[ "$output" != *"Port"* ]]
    [[ "$output" == *"IdentityFile ~/.ssh/id_ed25519_personal"* ]]
}

@test "add --port=N (equals form) is accepted" {
    run git-account add personal personal@gmail.com \
        /home/corazon/projects/private/personal github.com --port=22
    [ "$status" -eq 0 ]
    run cat "${HOME}/.ssh/config"
    [[ "$output" == *"HostName github.com"* ]]
    [[ "$output" != *"Port"* ]]
}

@test "add for an unknown platform defaults to standard SSH (no Port directive)" {
    run git-account add gitee gitee@gitee.com \
        /home/corazon/projects/private/gitee gitee.com
    [ "$status" -eq 0 ]
    run cat "${HOME}/.ssh/config"
    [[ "$output" == *"Host gitee.com"* ]]
    [[ "$output" == *"HostName gitee.com"* ]]
    [[ "$output" != *"Port"* ]]
}

@test "add for gitlab.com uses SSH-over-443 (alt.gitlab.com:443)" {
    run git-account add gitlab user@gitlab.com \
        /home/corazon/projects/private/gitlab gitlab.com
    [ "$status" -eq 0 ]
    run cat "${HOME}/.ssh/config"
    [[ "$output" == *"HostName alt.gitlab.com"* ]]
    [[ "$output" == *"Port 443"* ]]
}

@test "re-adding an existing account skips key generation and config entry" {
    # First add succeeds and creates the key.
    git-account add personal personal@gmail.com \
        /home/corazon/projects/private/personal github.com >/dev/null

    local key_file="${HOME}/.ssh/id_ed25519_personal"
    local config_file="${HOME}/.ssh/config"

    # Snapshot key and config before re-adding.
    local key_before config_before host_count_before
    key_before="$(cat "${key_file}")"
    config_before="$(cat "${config_file}")"
    host_count_before="$(grep -c '^Host github.com$' "${config_file}")"

    # Second add should skip key generation.
    run git-account add personal personal@gmail.com \
        /home/corazon/projects/private/personal github.com
    [ "$status" -eq 0 ]
    [[ "$output" == *"already exists"*"skipping key generation"* ]]

    # Key contents unchanged.
    [ "$key_before" == "$(cat "${key_file}")" ]

    # Config unchanged: still exactly one Host github.com entry.
    local host_count_after
    host_count_after="$(grep -c '^Host github.com$' "${config_file}")"
    [ "$host_count_before" -eq "$host_count_after" ]
    [ "$config_before" == "$(cat "${config_file}")" ]
}

@test "add requires exactly four arguments" {
    run git-account add only-one-arg
    [ "$status" -ne 0 ]
    [[ "$output" == *"add requires 4 arguments"* ]]
}
