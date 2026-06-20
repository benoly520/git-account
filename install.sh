#!/bin/bash
#
# git-account installer
#
# Usage:
#   1) Remote (one command, no clone needed):
#        curl -fsSL https://raw.githubusercontent.com/benoly520/git-account/master/install.sh | bash
#      (Review the script first if you like:
#        curl -fsSL <url> | less )
#
#   2) Local (from a clone, for contributors):
#        git clone https://github.com/benoly520/git-account.git
#        cd git-account && ./install.sh
#
# The installer detects whether it is running inside a repo checkout. If so,
# it installs the local src/git-account; otherwise it downloads the script
# from REMOTE_BASE (overridable via the env var of the same name).

set -euo pipefail

SCRIPT_NAME="git-account"
INSTALL_DIR="${HOME}/.local/bin"

# Default remote source for the script. Fork owners: override at runtime with
#   REMOTE_BASE=https://raw.githubusercontent.com/<you>/git-account/master bash install.sh
REMOTE_BASE="${REMOTE_BASE:-https://raw.githubusercontent.com/benoly520/git-account/master}"

# Terminal colors (disabled when not a TTY).
if [[ -t 1 ]]; then
    GREEN=$'\033[0;32m'; YELLOW=$'\033[0;33m'; RED=$'\033[0;31m'; RESET=$'\033[0m'
else
    GREEN=""; YELLOW=""; RED=""; RESET=""
fi

info()  { printf '%s🔧 %s%s\n' "${GREEN}" "$*" "${RESET}"; }
warn()  { printf '%s⚠️  %s%s\n' "${YELLOW}" "$*" "${RESET}" >&2; }
error() { printf '%s❌ %s%s\n' "${RED}" "$*" "${RESET}" >&2; }

# Resolve the git-account script source: prefer a local checkout, fall back
# to a remote download.
resolve_source() {
    local script_dir=""

    # When run as a file (./install.sh), BASH_SOURCE points at this script.
    if [[ -n "${BASH_SOURCE[0]:-}" ]]; then
        script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)" || script_dir=""
    fi

    # Local checkout next to this installer.
    if [[ -n "${script_dir}" && -f "${script_dir}/src/${SCRIPT_NAME}" ]]; then
        printf '%s\n' "${script_dir}/src/${SCRIPT_NAME}"
        return 0
    fi
    # Also honour CWD (e.g. user ran `bash install.sh` inside the repo).
    if [[ -f "src/${SCRIPT_NAME}" ]]; then
        printf '%s\n' "$(pwd)/src/${SCRIPT_NAME}"
        return 0
    fi

    # Otherwise download from the remote.
    if ! command -v curl >/dev/null 2>&1; then
        error "curl is required for remote install but was not found."
        error "Either install curl, or clone the repo and run ./install.sh locally."
        exit 1
    fi

    local tmp
    tmp="$(mktemp)"
    # shellcheck disable=SC2064
    trap "rm -f '${tmp}'" EXIT

    info "Downloading ${SCRIPT_NAME} from ${REMOTE_BASE} ..."
    if ! curl -fsSL "${REMOTE_BASE}/src/${SCRIPT_NAME}" -o "${tmp}"; then
        error "Failed to download ${REMOTE_BASE}/src/${SCRIPT_NAME}"
        error "Check the URL/network, or set REMOTE_BASE to the correct raw URL."
        exit 1
    fi
    printf '%s\n' "${tmp}"
}

# Ensure a `export PATH=...` line exists in the shell rc, without duplicating it.
ensure_path() {
    local rc_file
    # Prefer ~/.bashrc; fall back to ~/.profile if bashrc is absent.
    rc_file="${HOME}/.bashrc"
    [[ -f "${rc_file}" ]] || rc_file="${HOME}/.profile"

    # shellcheck disable=SC2016 # single quotes intentional: $HOME/$PATH must be literal in .bashrc
    local line='export PATH="$HOME/.local/bin:$PATH"'
    if [[ ":${PATH}:" == *":${INSTALL_DIR}:"* ]]; then
        info "${INSTALL_DIR} is already on PATH."
        return 0
    fi

    if grep -qF "${line}" "${rc_file}" 2>/dev/null; then
        info "PATH entry already present in ${rc_file}."
        warn "Run: source ${rc_file}  (or reopen the terminal) to activate it now."
    else
        printf '\n# Added by git-account installer\n%s\n' "${line}" >> "${rc_file}"
        info "Added ${INSTALL_DIR} to PATH in ${rc_file}."
        warn "Run: source ${rc_file}  (or reopen the terminal) to activate it."
    fi
}

main() {
    info "Installing git-account to ${INSTALL_DIR} ..."

    local src
    src="$(resolve_source)"

    mkdir -p "${INSTALL_DIR}"
    cp "${src}" "${INSTALL_DIR}/${SCRIPT_NAME}"
    chmod +x "${INSTALL_DIR}/${SCRIPT_NAME}"

    # Clean up a downloaded temp file (local mode: src is a real path, rm -f is safe).
    case "${src}" in
        /tmp/*) rm -f "${src}" ;;
    esac

    ensure_path

    # Self-check: if the binary is immediately usable, print its version.
    if "${INSTALL_DIR}/${SCRIPT_NAME}" version >/dev/null 2>&1; then
        info "Installation complete!"
        "${INSTALL_DIR}/${SCRIPT_NAME}" version
    else
        info "Installation complete. Activate PATH first, then run: git-account --help"
    fi
}

main "$@"
