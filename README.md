# git-account

> A lightweight Bash CLI tool that switches between multiple Git accounts automatically based on project path, using **SSH multi-key + Git `includeIf`**.

**Language / 语言:** English | [简体中文](README_CN.md)

When you juggle multiple accounts on the same machine — a personal GitHub, a company GitLab, Gitee, and so on — two things are notoriously painful:
- getting `user.name` / `user.email` mixed up in your commit history;
- manually switching SSH keys between accounts.

`git-account` does it all in one command: *generate a key → write `~/.ssh/config` → bind a project path → switch commit identity automatically*. Whichever directory you commit from, the correct account identity is used — no more manual `git config`.

---

## Table of Contents

- [Features](#features)
- [How It Works](#how-it-works)
- [Requirements](#requirements)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [Command Reference](#command-reference)
- [Generated Configuration Example](#generated-configuration-example)
- [Testing](#testing)
- [Development Guide](#development-guide)
- [Project Structure](#project-structure)
- [Roadmap](#roadmap)
- [Contributing](#contributing)
- [License](#license)

---

## Features

- **One-command account setup**: generates an `ed25519` SSH key, writes `~/.ssh/config`, creates a per-account Git identity file, and binds a project path.
- **Path-based identity switching**: leverages Git's `includeIf "gitdir:..."` so that `git commit` inside a given project directory automatically uses the right `user.name` / `user.email`.
- **Multiple accounts on the same platform**: `add-work` creates an SSH Host alias (e.g. `github-work`) so you can use a personal and a work account on GitHub simultaneously — just use `git@github-work:org/repo.git` as the remote URL.
- **Account queries**: `list` shows all accounts in a table; `current` shows the account matching the current directory along with the effective Git identity.
- **Switch and remove**: `switch` remaps an account to a new path; `remove` cleans up the Git identity config while **keeping the SSH key**, so other accounts that may reference it stay intact.
- **Idempotent and safe**: re-adding the same account skips key generation and config writes — no duplicate entries are ever created.
- **Firewall-friendly**: for `github.com` / `gitlab.com` it generates an SSH-over-443 config (`HostName ssh.github.com` + `Port 443`) by default, so it works out of the box on networks that block port 22. Pass `--port 22` to fall back to standard SSH.
- **Zero runtime dependencies**: relies only on `bash`, `git`, and `ssh-keygen` (all shipped with the system) — nothing extra to install.
- **Comprehensive test coverage**: every feature has corresponding [bats](https://github.com/bats-core/bats-core) automated tests and passes `shellcheck` static analysis.

---

## How It Works

```
┌──────────────────────────────────────────────────────────┐
│                     git-account CLI                       │
├──────────────────────────────────────────────────────────┤
│  Command layer (case/esac)                                │
│   add / add-work / list / current / switch / remove      │
│   help / version                                         │
├──────────────────────────────────────────────────────────┤
│  Core functions                                           │
│   add_account()       SSH key + config + identity + meta │
│   list_accounts()     read accounts.txt, format output   │
│   show_current()      path match + resolve Git identity  │
│   switch_account()    modify includeIf mapping           │
│   remove_account()    clean identity/includeIf/metadata  │
├──────────────────────────────────────────────────────────┤
│  Data layer (under ~/$HOME)                               │
│   ~/.ssh/config          SSH Host rules                   │
│   ~/.ssh/id_ed25519_*    per-account private/public keys  │
│   ~/.gitconfig           includeIf conditional includes   │
│   ~/.git-account/        account metadata + identity cfg  │
│   ~/.git-account/accounts.txt   account index             │
└──────────────────────────────────────────────────────────┘
```

**The core of identity switching** is Git's `includeIf` directive: a conditional include is added to `~/.gitconfig` for each project path. Whenever you operate inside a Git repository under that path, Git automatically loads the corresponding identity config file and uses the correct `user.name` / `user.email`.

---

## Requirements

| Dependency | Minimum | Notes |
|------------|---------|-------|
| Bash | 4.0+ | Uses `[[ =~ ]]` and related features |
| Git | 2.28+ | `includeIf` with `gitdir:` patterns requires a recent version |
| OpenSSH | 8.0+ | `ssh-keygen` for ed25519 key generation |

> Works on Linux / WSL 2 / macOS. Windows users are advised to run it inside WSL 2 or Git Bash.

---

## Installation

### Option 1: One-command install (recommended)

No need to clone the repo — run this in your terminal:

```bash
curl -fsSL https://raw.githubusercontent.com/benoly520/git-account/master/install.sh | bash
```

The installer downloads the `git-account` script, places it in `~/.local/bin/`, ensures that directory is on your `PATH`, and prints the installed version. If the command is not found afterwards, run `source ~/.bashrc` (or reopen the terminal) to activate the new `PATH`.

> **Security note**: piping to `bash` runs whatever the URL returns. If you prefer to review first:
> ```bash
> curl -fsSL https://raw.githubusercontent.com/benoly520/git-account/master/install.sh | less
> ```
> then re-run with `| bash` once you are satisfied.

### Option 2: Install from source (for contributors)

```bash
git clone https://github.com/benoly520/git-account.git
cd git-account
./install.sh
```

When run inside a clone, the installer uses the local `src/git-account` (handy for testing changes). It can also be copied manually:

```bash
chmod +x src/git-account
sudo cp src/git-account /usr/local/bin/        # or any directory on your PATH
```

### Verify the installation

```bash
git-account version
# Output: git-account version 0.1.0
```

> **For fork maintainers**: the installer's `REMOTE_BASE` defaults to the upstream repo. To point it at your fork, override at runtime:
> `REMOTE_BASE=https://raw.githubusercontent.com/<you>/git-account/master bash install.sh`

---

## Quick Start

Suppose you have two accounts: a personal GitHub account `personal@gmail.com` and a company GitHub account `work@company.com`.

```bash
# 1. Add the personal account (bound to your personal project directory)
git-account add personal personal@gmail.com \
    /home/you/projects/personal github.com

# 2. Add the work account (same platform, multiple accounts — uses a Host alias)
git-account add-work github-work work@company.com \
    /home/you/projects/work github.com

# 3. List all configured accounts
git-account list

# 4. cd into the personal project directory and confirm the active identity
cd /home/you/projects/personal
git-account current
# Output: 当前目录匹配账号: personal
#         当前 Git 身份: personal <personal@gmail.com>

# 5. Clone a work repo using the alias
git clone git@github-work:your-org/repo.git
```

From now on, committing in any Git repository under a bound path automatically uses the corresponding account identity — no manual `git config` required.

---

## Command Reference

### `add` — Add an account

```bash
git-account add <name> <email> <project_path> <domain> [--port <N>]
```

- Generates `~/.ssh/id_ed25519_<name>` (ed25519, empty passphrase)
- Adds a `Host <domain>` entry to `~/.ssh/config`
- Creates `~/.git-account/<name>.gitconfig` (with `user.name` / `user.email`)
- Adds an `[includeIf "gitdir:<project_path>/"]` entry to `~/.gitconfig`
- Records account metadata in `~/.git-account/accounts.txt`

For known platforms (`github.com`, `gitlab.com`) it defaults to an SSH-over-443 config (e.g. `HostName ssh.github.com` + `Port 443`), which works through firewalls that block port 22. Pass `--port 22` to fall back to standard SSH. Unknown platforms default to standard SSH (port 22).

Use this when you have a single account per platform.

### `add-work` — Add a work account (same platform, multiple accounts)

```bash
git-account add-work <name> <email> <project_path> <domain> [--port <N>]
```

Like `add`, but the SSH `Host` uses `<name>` as an alias (e.g. `github-work`) and `HostName` points to the resolved endpoint. Use the alias in the remote URL when cloning:

```bash
git clone git@github-work:org/repo.git
```

### `list` — List all accounts

```bash
git-account list
```

Prints a table of every account's `NAME` / `EMAIL` / `PROJECT_PATH` / `DOMAIN` / `KEY_PATH`. Shows "暂无已配置的账号" (no accounts configured) when there are none.

### `current` — Show the account matching the current directory

```bash
git-account current
```

Matches the current working directory against each account's `project_path` (subdirectories are supported), prints the matching account details, and resolves the effective Git identity via `git config`. Prints a notice and exits non-zero when nothing matches.

### `switch` — Switch an account to a new path

```bash
git-account switch <name> <target_path>
```

Remaps an account to a new project path: removes the old path's `includeIf`, removes any `includeIf` already on the target path, adds a fresh `includeIf`, and updates `accounts.txt`. The SSH key and `~/.ssh/config` are left untouched.

### `remove` — Remove an account

```bash
git-account remove <name>
```

- Deletes `~/.git-account/<name>.gitconfig`
- Removes the matching `includeIf` entry from `~/.gitconfig`
- Deletes the account line from `accounts.txt`

> **Note**: for safety, `remove` does **not** delete SSH keys or `~/.ssh/config` entries, to avoid breaking other accounts that may reuse the same key. To clean up completely, manually delete `~/.ssh/id_ed25519_<name>` and the corresponding `Host` entry.

### `help` / `version`

```bash
git-account help          # or --help / -h
git-account version       # or --version / -v
git-account               # no arguments → shows help
```

---

## Generated Configuration Example

After adding a personal GitHub account, the generated config looks like this (github.com defaults to SSH-over-443):

**`~/.ssh/config`**

```sshconfig
# personal (personal@gmail.com)
Host github.com
    HostName ssh.github.com
    User git
    Port 443
    IdentityFile ~/.ssh/id_ed25519_personal
    IdentitiesOnly yes
```

**`~/.git-account/personal.gitconfig`**

```ini
[user]
    name = personal
    email = personal@gmail.com
```

**`~/.gitconfig`**

```ini
[includeIf "gitdir:/home/you/projects/personal/"]
    path = ~/.git-account/personal.gitconfig
```

**`~/.git-account/accounts.txt`**

```
personal|personal@gmail.com|/home/you/projects/personal|github.com|~/.ssh/id_ed25519_personal
```

---

## Testing

This project is tested with [bats-core](https://github.com/bats-core/bats-core). Every test runs in an isolated temporary `$HOME`, so it **never** touches your real `~/.ssh` or `~/.gitconfig`.

### Install test dependencies

```bash
# Install bats (either works)
npm install -g bats
# Or from source: git clone https://github.com/bats-core/bats-core.git && cd bats-core && ./install.sh ~/.local

# Install shellcheck (for static analysis)
sudo apt install shellcheck           # Debian/Ubuntu
brew install shellcheck               # macOS
```

### Run the tests

```bash
cd git-account

# Run the full suite
bats test/*.bats

# Static analysis
shellcheck src/git-account
```

### Test case overview

Tests are split into 5 files by module, totaling **31 test cases** that cover the happy path, edge cases, and error handling of every command:

| Test file | Cases | Coverage |
|-----------|-------|----------|
| `t1-init.bats` | 7 | Framework behavior of help/version commands |
| `t2-ssh.bats` | 8 | SSH key generation, `~/.ssh/config` writes, and port/platform resolution |
| `t3-identity.bats` | 5 | Git identity config, `includeIf`, and metadata persistence |
| `t4-query.bats` | 5 | Account listing and current-directory identity lookup |
| `t5-switch-remove.bats` | 6 | Account switching and removal |

#### `t1-init.bats` — Project initialization

Verifies the basic framework behavior, ensuring `help`/`version` respond correctly in every invocation form.

- `help`, `--help`, `-h` all show the help message (first-line title is checked)
- `version`, `--version`, `-v` all print `git-account version 0.1.0`
- Running with no arguments defaults to showing help
- `setup()` creates a temporary `$HOME` and `bin` directory; `teardown()` cleans up

#### `t2-ssh.bats` — SSH key management

Verifies key generation, `~/.ssh/config` writes, and port/platform resolution for `add` / `add-work`.

- `add` generates an ed25519 key (public key header checked as `ssh-ed25519`); github.com defaults to `HostName ssh.github.com` + `Port 443`
- `add-work` generates a `Host=<name>` alias entry pointing at the resolved endpoint, with no bare-domain entry
- `--port 22` falls back to standard SSH (`HostName=domain`, no `Port` directive)
- `--port=N` (equals form) is accepted
- Unknown platforms (e.g. `gitee.com`) default to standard SSH with no `Port` directive
- `gitlab.com` uses `alt.gitlab.com:443`
- Re-adding the same account skips key generation; key contents and `Host` count are unchanged (idempotent)
- Missing arguments exit non-zero with an error

#### `t3-identity.bats` — Git identity management

Verifies the Git identity config and metadata persistence inside `add_account()`.

- Generates `~/.git-account/<name>.gitconfig` containing `user.name` and `user.email`
- The `includeIf` in `~/.gitconfig` uses an **absolute path** (e.g. `gitdir:/home/you/projects/personal/`), never a relative one
- The `accounts.txt` metadata strictly matches `name|email|project_path|domain|key_path`, with `key_path` as an absolute path
- `add-work` likewise generates identity, `includeIf`, and metadata
- Re-adding produces no duplicate `includeIf` entries or metadata lines

#### `t4-query.bats` — Account queries and display

Verifies the `list` and `current` commands.

- `list` table output includes every field of all accounts
- `list` shows "暂无已配置的账号" when there are no accounts
- `current` matches an account inside a project directory and resolves the effective Git identity via `includeIf` (e.g. `personal <personal@gmail.com>`)
- `current` supports matching **subdirectories** of a project path
- `current` prints a notice and exits non-zero when nothing matches

#### `t5-switch-remove.bats` — Account switch and removal

Verifies the `switch` and `remove` commands and their side-effect control.

- After `switch`: the old path's `includeIf` is gone, the new path's `includeIf` is present, `accounts.txt`'s `project_path` is updated, and the identity file is kept
- When the target path is already owned by another account, `switch` removes the old entry first, then adds — ending up with exactly one entry pointing at the correct account
- `switch` on a non-existent account errors out
- `remove` deletes the identity file, the `includeIf` entry, and the `accounts.txt` line without affecting other accounts
- `remove` does **not** delete SSH keys or `~/.ssh/config` entries (explicitly asserts the key file and `Host` entry still exist)
- `remove` on a non-existent account does not crash and reports accordingly

### Expected output

```text
$ bats test/*.bats
t1-init.bats
 ✓ git-account help displays the help message
 ✓ git-account --help displays the help message
 ... (7 total)

t2-ssh.bats
 ✓ add generates an ed25519 key and a Host=<domain> config entry
 ... (8 total)

t3-identity.bats
 ... (5 total)

t4-query.bats
 ... (5 total)

t5-switch-remove.bats
 ... (6 total)

31 tests, 0 failures
```

---

## Development Guide

### Project structure

```
git-account/
├── src/
│   └── git-account           # Main executable script (single file, all logic)
├── test/
│   ├── t1-init.bats          # Framework initialization tests
│   ├── t2-ssh.bats           # SSH key management tests
│   ├── t3-identity.bats      # Git identity management tests
│   ├── t4-query.bats         # Account query tests
│   └── t5-switch-remove.bats # Switch and remove tests
├── install.sh                # One-line install script
├── LICENSE
├── README.md                 # English docs (default)
├── README_CN.md              # Chinese docs
└── .gitignore
```

### Development workflow

1. After editing `src/git-account`, run static analysis first:
   ```bash
   shellcheck src/git-account
   ```
2. Run the relevant tests:
   ```bash
   bats test/<module>.bats
   ```
3. Before committing, run the full suite to ensure no regressions:
   ```bash
   bats test/*.bats
   ```

### Test isolation

Each test file's `setup()` uses `mktemp -d` to create a temporary directory as `$HOME` and symlinks the script into a temporary `bin` directory. All writes to `~/.ssh`, `~/.gitconfig`, and `~/.git-account` happen inside the temp directory, and `teardown()` cleans up automatically — tests never pollute your development environment.

### Adding a new command

1. Implement the new function in `src/git-account` (follow the existing `set -euo pipefail` and `local`-variable style)
2. Add command dispatch and argument validation in `main()`'s `case` statement
3. Update the help text in `show_help()`
4. Create or extend a `.bats` test file under `test/`
5. Verify with `shellcheck` and `bats`

---

## Roadmap

- [x] v0.1.0 — Core features: `add` / `add-work` / `list` / `current` / `switch` / `remove`
- [x] Firewall-friendly: known platforms default to SSH-over-443, with `--port` override
- [ ] `doctor` — diagnose the current config and flag missing or incorrect settings
- [ ] `--dry-run` — preview the config changes without writing
- [ ] `sync` — bulk import accounts from a YAML/JSON config file
- [ ] `init` — interactive setup wizard
- [ ] Native Windows support (Git Bash)

---

## Contributing

Issues and Pull Requests are welcome!

1. Fork this repository
2. Create a feature branch: `git checkout -b feature/your-feature`
3. Commit your changes: `git commit -m 'feat: add your feature'` (following [Conventional Commits](https://www.conventionalcommits.org/) is recommended)
4. Push the branch: `git push origin feature/your-feature`
5. Open a Pull Request

Please make sure your PR passes `shellcheck src/git-account` and the full `bats test/*.bats` suite.

---

## License

This project is open-sourced under the [MIT License](LICENSE).

---

<sub>If this project helps you, a Star ⭐ is appreciated.</sub>
