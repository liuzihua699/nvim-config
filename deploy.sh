#!/usr/bin/env bash
set -euo pipefail

REPO="https://github.com/liuzihua699/nvim-config.git"
CONF="$HOME/.config/nvim"
DIRS=("$CONF" "$HOME/.local/share/nvim" "$HOME/.local/state/nvim" "$HOME/.cache/nvim")

backup_and_remove() {
    for d in "${DIRS[@]}"; do
        [ -d "$d" ] && mv "$d" "${d}.bak.$(date +%s)" && echo "备份: $d"
    done
}

case "${1:-}" in
install)
    backup_and_remove
    git clone "$REPO" "$CONF"
    echo "安装完成，运行 nvim 自动安装插件"
    ;;
uninstall)
    for d in "${DIRS[@]}"; do
        rm -rf "$d" && echo "已删除: $d"
    done
    echo "卸载完成"
    ;;
*)
    echo "用法: $0 {install|uninstall}"
    exit 1
    ;;
esac
