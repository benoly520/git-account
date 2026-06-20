# git-account

> 一个轻量级 Bash CLI 工具，通过 **SSH 多密钥 + Git `includeIf`** 实现基于项目路径的 Git 多账号自动切换。

**语言 / Language:** [English](README.md) | 简体中文

在同一台机器上同时使用个人 GitHub、公司 GitLab、Gitee 等多个账号时，最让人头疼的两件事是：
- 提交记录里的 `user.name` / `user.email` 经常搞混；
- 不同账号的 SSH 密钥需要手动切换。

`git-account` 用一条命令完成"生成密钥 → 写入 `~/.ssh/config` → 绑定项目路径 → 自动切换提交身份"，让你在哪个目录下提交，就自动用哪个账号的身份，无需手动 `git config`。

---

## 目录

- [功能特性](#功能特性)
- [工作原理](#工作原理)
- [环境要求](#环境要求)
- [安装](#安装)
- [快速开始](#快速开始)
- [命令参考](#命令参考)
- [生成的配置示例](#生成的配置示例)
- [测试](#测试)
- [开发指南](#开发指南)
- [项目结构](#项目结构)
- [路线图](#路线图)
- [贡献](#贡献)
- [许可证](#许可证)

---

## 功能特性

- **一键添加账号**：自动生成 `ed25519` SSH 密钥、写入 `~/.ssh/config`、创建 per-account Git 身份文件、绑定项目路径。
- **按路径自动切换身份**：利用 Git 的 `includeIf "gitdir:..."` 机制，进入对应项目目录后 `git commit` 自动使用正确的 `user.name` / `user.email`。
- **同平台多账号支持**：`add-work` 生成 SSH Host 别名（如 `github-work`），让你在同一平台（如 GitHub）上同时使用个人号与工作号，远端 URL 用 `git@github-work:org/repo.git` 即可。
- **账号查询**：`list` 表格化展示所有账号；`current` 显示当前目录匹配的账号及实际生效的 Git 身份。
- **账号切换与删除**：`switch` 将账号重新映射到新路径；`remove` 清理 Git 身份配置但**保留 SSH 密钥**，避免误伤其他账号。
- **幂等安全**：重复添加同一账号会自动跳过密钥生成与配置写入，不会产生重复条目。
- **防火墙友好**：对 `github.com` / `gitlab.com` 默认生成 SSH-over-443 配置（`HostName ssh.github.com` + `Port 443`），无需手动改 config 即可穿透封禁 22 端口的网络；可用 `--port 22` 回退标准 SSH。
- **零运行时依赖**：仅依赖 `bash`、`git`、`ssh-keygen`（系统自带），无需安装任何额外运行时。
- **完整测试覆盖**：每个功能均有对应的 [bats](https://github.com/bats-core/bats-core) 自动化测试，并通过 `shellcheck` 静态检查。

---

## 工作原理

```
┌──────────────────────────────────────────────────────────┐
│                     git-account CLI                       │
├──────────────────────────────────────────────────────────┤
│  命令层 (case/esac)                                       │
│   add / add-work / list / current / switch / remove      │
│   help / version                                         │
├──────────────────────────────────────────────────────────┤
│  核心函数层                                               │
│   add_account()       SSH 密钥 + config + 身份 + 元数据  │
│   list_accounts()     读取 accounts.txt 并格式化输出     │
│   show_current()      路径匹配 + 解析当前 Git 身份       │
│   switch_account()    修改 includeIf 映射                │
│   remove_account()    清理身份/includeIf/元数据          │
├──────────────────────────────────────────────────────────┤
│  数据层 (~/$HOME 下)                                      │
│   ~/.ssh/config          SSH Host 规则                    │
│   ~/.ssh/id_ed25519_*    各账号私钥/公钥                  │
│   ~/.gitconfig           includeIf 条件包含               │
│   ~/.git-account/        账号元数据 + 身份配置            │
│   ~/.git-account/accounts.txt   账号索引                  │
└──────────────────────────────────────────────────────────┘
```

**身份切换的核心**是 Git 的 `includeIf` 指令：在 `~/.gitconfig` 中为每个项目路径添加一条条件包含，当你在该路径下的 Git 仓库中操作时，Git 会自动加载对应的身份配置文件，从而使用正确的 `user.name` / `user.email`。

---

## 环境要求

| 依赖 | 最低版本 | 说明 |
|------|----------|------|
| Bash | 4.0+ | 使用了 `[[ =~ ]]`、关联特性等 |
| Git | 2.28+ | `includeIf` 的 `gitdir:` 模式需要较新版本 |
| OpenSSH | 8.0+ | `ssh-keygen` 生成 ed25519 密钥 |

> 适用于 Linux / WSL 2 / macOS。Windows 用户建议在 WSL 2 或 Git Bash 中使用。

---

## 安装

### 方式一：一键安装脚本（推荐）

```bash
git clone https://github.com/<your-username>/git-account.git
cd git-account
./install.sh
```

`install.sh` 会将 `git-account` 复制到 `~/.local/bin/` 并确保该目录在 `PATH` 中。安装完成后执行：

```bash
git-account --help
```

看到帮助信息即表示安装成功。若提示命令未找到，请执行 `source ~/.bashrc` 或重开终端。

### 方式二：手动安装

```bash
git clone https://github.com/<your-username>/git-account.git
cd git-account
chmod +x src/git-account
sudo cp src/git-account /usr/local/bin/        # 或复制到任意 PATH 目录
```

### 验证安装

```bash
git-account version
# 输出: git-account version 0.1.0
```

---

## 快速开始

假设你有两个账号：个人 GitHub 账号 `personal@gmail.com`，公司 GitHub 账号 `work@company.com`。

```bash
# 1. 添加个人账号（绑定到个人项目目录）
git-account add personal personal@gmail.com \
    /home/you/projects/personal github.com

# 2. 添加工作账号（同平台多账号，使用 Host 别名）
git-account add-work github-work work@company.com \
    /home/you/projects/work github.com

# 3. 查看所有已配置账号
git-account list

# 4. 进入个人项目目录，确认当前身份
cd /home/you/projects/personal
git-account current
# 输出: 当前目录匹配账号: personal
#       当前 Git 身份: personal <personal@gmail.com>

# 5. 克隆工作仓库时使用别名
git clone git@github-work:your-org/repo.git
```

之后在任何已绑定路径下的 Git 仓库中提交，都会自动使用对应的账号身份，无需手动 `git config`。

---

## 命令参考

### `add` — 添加账号

```bash
git-account add <name> <email> <project_path> <domain> [--port <N>]
```

- 生成 `~/.ssh/id_ed25519_<name>` 密钥（ed25519，空密码）
- 在 `~/.ssh/config` 添加 `Host <domain>` 条目
- 创建 `~/.git-account/<name>.gitconfig`（含 `user.name` / `user.email`）
- 在 `~/.gitconfig` 添加 `[includeIf "gitdir:<project_path>/"]` 条目
- 在 `~/.git-account/accounts.txt` 记录账号元数据

对已知平台（`github.com`、`gitlab.com`）默认生成 SSH-over-443 配置（如 `HostName ssh.github.com` + `Port 443`），可穿透封禁 22 端口的防火墙；传入 `--port 22` 可回退标准 SSH。未知平台默认走标准 SSH（端口 22）。

适用于每个平台只有一个账号的场景。

### `add-work` — 添加工作账号（同平台多账号）

```bash
git-account add-work <name> <email> <project_path> <domain> [--port <N>]
```

与 `add` 类似，但 SSH `Host` 使用 `<name>` 作为别名（如 `github-work`），`HostName` 指向解析后的端点。克隆仓库时远端 URL 使用别名：

```bash
git clone git@github-work:org/repo.git
```

### `list` — 列出所有账号

```bash
git-account list
```

以表格形式展示所有账号的 `NAME` / `EMAIL` / `PROJECT_PATH` / `DOMAIN` / `KEY_PATH`。无账号时提示"暂无已配置的账号"。

### `current` — 显示当前目录匹配的账号

```bash
git-account current
```

根据当前工作目录匹配账号的 `project_path`（支持子目录），显示匹配的账号信息及通过 `git config` 解析出的实际 Git 身份。无匹配时提示并以非零码退出。

### `switch` — 切换账号到新路径

```bash
git-account switch <name> <target_path>
```

将账号重新映射到新的项目路径：移除旧路径的 `includeIf`、移除目标路径上可能存在的 `includeIf`、添加新的 `includeIf`、更新 `accounts.txt`。SSH 密钥与 `~/.ssh/config` 不受影响。

### `remove` — 删除账号

```bash
git-account remove <name>
```

- 删除 `~/.git-account/<name>.gitconfig`
- 移除 `~/.gitconfig` 中对应的 `includeIf` 条目
- 从 `accounts.txt` 删除该账号行

> **注意**：出于安全考虑，`remove` **不会**删除 SSH 密钥和 `~/.ssh/config` 条目，避免影响可能复用同一密钥的其他账号。如需彻底清理，请手动删除 `~/.ssh/id_ed25519_<name>` 及对应的 `Host` 条目。

### `help` / `version`

```bash
git-account help          # 或 --help / -h
git-account version       # 或 --version / -v
git-account               # 无参数时默认显示帮助
```

---

## 生成的配置示例

添加个人 GitHub 账号后，自动生成的配置如下（github.com 默认走 SSH-over-443）：

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

## 测试

本项目使用 [bats-core](https://github.com/bats-core/bats-core) 进行测试，所有测试均在隔离的临时 `$HOME` 环境中运行，**不会**触碰你真实的 `~/.ssh` 或 `~/.gitconfig`。

### 安装测试依赖

```bash
# 安装 bats（任选一种）
npm install -g bats
# 或从源码安装: git clone https://github.com/bats-core/bats-core.git && cd bats-core && ./install.sh ~/.local

# 安装 shellcheck（用于静态检查）
sudo apt install shellcheck           # Debian/Ubuntu
brew install shellcheck               # macOS
```

### 运行测试

```bash
cd git-account

# 运行全部测试
bats test/*.bats

# 静态检查
shellcheck src/git-account
```

### 测试用例说明

测试按任务模块拆分为 5 个文件，共 **31 个测试用例**，覆盖所有命令的正常路径、边界条件与错误处理：

| 测试文件 | 用例数 | 覆盖内容 |
|----------|--------|----------|
| `t1-init.bats` | 7 | 帮助与版本命令的框架行为 |
| `t2-ssh.bats` | 8 | SSH 密钥生成、`~/.ssh/config` 写入与端口/平台解析 |
| `t3-identity.bats` | 5 | Git 身份配置、`includeIf`、元数据记录 |
| `t4-query.bats` | 5 | 账号列表与当前目录身份查询 |
| `t5-switch-remove.bats` | 6 | 账号切换与删除 |

#### `t1-init.bats` — 项目初始化

验证 CLI 框架基础行为，确保 `help`/`version` 命令在任何调用形式下都能正确响应。

- `help`、`--help`、`-h` 均显示帮助信息（首行标题校验）
- `version`、`--version`、`-v` 均显示 `git-account version 0.1.0`
- 无参数运行时默认显示帮助
- `setup()` 创建临时 `$HOME` 与 `bin` 目录，`teardown()` 清理

#### `t2-ssh.bats` — SSH 密钥管理

验证 `add` / `add-work` 的密钥生成、`~/.ssh/config` 写入与端口/平台解析逻辑。

- `add` 生成 ed25519 密钥（校验公钥头为 `ssh-ed25519`），github.com 默认写入 `HostName ssh.github.com` + `Port 443`
- `add-work` 生成 `Host=<name>` 别名条目指向解析后的端点，且不产生裸 domain 条目
- `--port 22` 回退标准 SSH（`HostName=domain`，不写 `Port` 指令）
- `--port=N` 等号形式可用
- 未知平台（如 `gitee.com`）默认标准 SSH，无 `Port` 指令
- `gitlab.com` 使用 `alt.gitlab.com:443`
- 重复添加同一账号时跳过密钥生成，密钥内容与 `Host` 计数不变（幂等）
- 参数不足时非零退出并报错

#### `t3-identity.bats` — Git 身份管理

验证 `add_account()` 中的 Git 身份配置与元数据持久化。

- 生成 `~/.git-account/<name>.gitconfig`，包含 `user.name` 与 `user.email`
- `~/.gitconfig` 中的 `includeIf` 使用**绝对路径**（如 `gitdir:/home/you/projects/personal/`），不含相对路径
- `accounts.txt` 元数据格式严格匹配 `name|email|project_path|domain|key_path`，`key_path` 为绝对路径
- `add-work` 同样生成身份、`includeIf` 与元数据
- 重复添加不产生重复的 `includeIf` 条目或元数据行

#### `t4-query.bats` — 账号查询与显示

验证 `list` 与 `current` 命令。

- `list` 表格输出包含所有账号的各字段
- `list` 无账号时显示"暂无已配置的账号"
- `current` 在项目目录内匹配账号，并通过 `includeIf` 解析出实际 Git 身份（如 `personal <personal@gmail.com>`）
- `current` 支持匹配项目路径的**子目录**
- `current` 无匹配时提示并以非零码退出

#### `t5-switch-remove.bats` — 账号切换与删除

验证 `switch` 与 `remove` 命令及其副作用控制。

- `switch` 切换路径后：旧路径 `includeIf` 消失、新路径 `includeIf` 出现、`accounts.txt` 的 `project_path` 更新、身份文件保留
- `switch` 目标路径已被其他账号占用时，先删除旧条目再添加，最终仅保留一条且指向正确账号
- `switch` 不存在的账号时报错退出
- `remove` 删除身份文件、`includeIf` 条目、`accounts.txt` 行，且不影响其他账号
- `remove` **不删除** SSH 密钥与 `~/.ssh/config` 条目（显式校验密钥文件与 `Host` 条目仍存在）
- `remove` 不存在的账号时不崩溃并提示

### 预期输出

```text
$ bats test/*.bats
t1-init.bats
 ✓ git-account help displays the help message
 ✓ git-account --help displays the help message
 ... (共 7 项)

t2-ssh.bats
 ✓ add generates an ed25519 key and a Host=<domain> config entry
 ... (共 8 项)

t3-identity.bats
 ... (共 5 项)

t4-query.bats
 ... (共 5 项)

t5-switch-remove.bats
 ... (共 6 项)

31 tests, 0 failures
```

---

## 开发指南

### 项目结构

```
git-account/
├── src/
│   └── git-account           # 主可执行脚本（单文件，含所有逻辑）
├── test/
│   ├── t1-init.bats          # 框架初始化测试
│   ├── t2-ssh.bats           # SSH 密钥管理测试
│   ├── t3-identity.bats      # Git 身份管理测试
│   ├── t4-query.bats         # 账号查询测试
│   └── t5-switch-remove.bats # 切换与删除测试
├── install.sh                # 一键安装脚本
├── LICENSE
├── README.md                 # 英文文档（默认）
├── README_CN.md              # 中文文档
└── .gitignore
```

### 开发流程

1. 修改 `src/git-account` 后，先运行静态检查：
   ```bash
   shellcheck src/git-account
   ```
2. 运行相关测试：
   ```bash
   bats test/<对应模块>.bats
   ```
3. 提交前运行全量测试确保无回归：
   ```bash
   bats test/*.bats
   ```

### 测试隔离机制

每个测试文件的 `setup()` 会用 `mktemp -d` 创建临时目录作为 `$HOME`，并把脚本软链到临时 `bin` 目录。所有 `~/.ssh`、`~/.gitconfig`、`~/.git-account` 的写入都发生在临时目录中，`teardown()` 自动清理，确保测试不会污染开发环境。

### 添加新命令

1. 在 `src/git-account` 中实现新函数（遵循现有 `set -euo pipefail` 与 `local` 变量风格）
2. 在 `main()` 的 `case` 语句中添加命令分发与参数校验
3. 更新 `show_help()` 的帮助文本
4. 在 `test/` 下新建或扩展 `.bats` 测试文件
5. 运行 `shellcheck` 与 `bats` 验证

---

## 路线图

- [x] v0.1.0 — 核心功能：`add` / `add-work` / `list` / `current` / `switch` / `remove`
- [x] 防火墙友好：已知平台默认 SSH-over-443，`--port` 覆盖
- [ ] `doctor` — 诊断当前配置，提示缺失或错误的设置
- [ ] `--dry-run` — 预览将要修改的配置，不实际写入
- [ ] `sync` — 通过 YAML/JSON 配置文件批量导入账号
- [ ] `init` — 交互式初始化向导
- [ ] Windows 原生环境（Git Bash）支持

---

## 贡献

欢迎提交 Issue 和 Pull Request！

1. Fork 本仓库
2. 创建特性分支：`git checkout -b feature/your-feature`
3. 提交更改：`git commit -m 'feat: add your feature'`（建议遵循 [Conventional Commits](https://www.conventionalcommits.org/)）
4. 推送分支：`git push origin feature/your-feature`
5. 提交 Pull Request

请确保 PR 通过 `shellcheck src/git-account` 与 `bats test/*.bats` 全部测试。

---

## 许可证

本项目采用 [MIT License](LICENSE) 开源。

---

<sub>若该项目对你有帮助，欢迎 Star ⭐ 支持。</sub>
