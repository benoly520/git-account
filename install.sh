#!/bin/bash
# git-account 一键安装脚本

set -e

INSTALL_DIR="$HOME/.local/bin"
SCRIPT_NAME="git-account"
SCRIPT_SRC="src/git-account"

echo "🔧 正在安装 git-account..."
mkdir -p "$INSTALL_DIR"
cp "$SCRIPT_SRC" "$INSTALL_DIR/$SCRIPT_NAME"
chmod +x "$INSTALL_DIR/$SCRIPT_NAME"

# 确保 PATH 包含 ~/.local/bin
if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
    echo "✅ 已将 ~/.local/bin 添加到 PATH，请执行 source ~/.bashrc 或重启终端"
else
    echo "✅ ~/.local/bin 已在 PATH 中"
fi

echo "✅ 安装完成！执行 git-account --help 验证"
