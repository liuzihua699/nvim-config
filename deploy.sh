#!/usr/bin/env bash
set -euo pipefail

readonly REPO_URL="${NVIM_DEPLOY_REPO_URL:-https://github.com/liuzihua699/nvim-config.git}"
readonly REPO_BRANCH="${NVIM_DEPLOY_BRANCH:-main}"
readonly MIN_NVIM_VERSION="0.11.2"
readonly NVIM_VERSION="0.11.6"
readonly MIN_NODE_VERSION="18.0.0"
readonly NODE_VERSION="22.19.0"
readonly LAZYGIT_VERSION="0.64.1"

readonly USER_HOME="${HOME:?无法确定用户主目录}"
readonly CONFIG_HOME="${XDG_CONFIG_HOME:-$USER_HOME/.config}"
readonly DATA_HOME="${XDG_DATA_HOME:-$USER_HOME/.local/share}"
readonly STATE_HOME="${XDG_STATE_HOME:-$USER_HOME/.local/state}"
readonly CACHE_HOME="${XDG_CACHE_HOME:-$USER_HOME/.cache}"
readonly CONF_DIR="$CONFIG_HOME/nvim"
readonly DATA_DIR="$DATA_HOME/nvim"
readonly STATE_DIR="$STATE_HOME/nvim"
readonly CACHE_DIR="$CACHE_HOME/nvim"
readonly DEPLOY_DATA_DIR="$DATA_HOME/nvim-deploy"
readonly BACKUP_ROOT="$STATE_HOME/nvim-deploy/backups"
readonly LOCAL_BIN="$USER_HOME/.local/bin"

ASSUME_YES=0
LAST_BACKUP_DIR=""

if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
    readonly COLOR_BLUE=$'\033[34m'
    readonly COLOR_GREEN=$'\033[32m'
    readonly COLOR_YELLOW=$'\033[33m'
    readonly COLOR_RED=$'\033[31m'
    readonly COLOR_BOLD=$'\033[1m'
    readonly COLOR_RESET=$'\033[0m'
else
    readonly COLOR_BLUE=""
    readonly COLOR_GREEN=""
    readonly COLOR_YELLOW=""
    readonly COLOR_RED=""
    readonly COLOR_BOLD=""
    readonly COLOR_RESET=""
fi

info() {
    printf '%s[信息]%s %s\n' "$COLOR_BLUE" "$COLOR_RESET" "$*"
}

success() {
    printf '%s[完成]%s %s\n' "$COLOR_GREEN" "$COLOR_RESET" "$*"
}

warn() {
    printf '%s[提示]%s %s\n' "$COLOR_YELLOW" "$COLOR_RESET" "$*"
}

error() {
    printf '%s[错误]%s %s\n' "$COLOR_RED" "$COLOR_RESET" "$*" >&2
}

die() {
    error "$*"
    return 1
}

read_input() {
    local variable_name="$1"
    local prompt="$2"
    local value=""

    if [[ -t 1 && -r /dev/tty ]]; then
        IFS= read -r -p "$prompt" value </dev/tty || return 1
    else
        printf '%s' "$prompt"
        IFS= read -r value || return 1
    fi
    printf -v "$variable_name" '%s' "$value"
}

confirm() {
    local prompt="$1"
    local answer=""

    if ((ASSUME_YES == 1)); then
        return 0
    fi
    read_input answer "$prompt [y/N] " || return 1
    [[ "$answer" =~ ^[Yy]$ ]]
}

pause_menu() {
    if [[ -t 1 && -r /dev/tty ]]; then
        IFS= read -r -p "按回车键返回菜单..." </dev/tty || true
    fi
}

version_ge() {
    local current="$1"
    local required="$2"
    [[ "$(printf '%s\n%s\n' "$required" "$current" | sort -V | head -n1)" == "$required" ]]
}

assert_safe_nvim_path() {
    local target="${1:-}"
    [[ -n "$target" ]] || return 1
    [[ "$target" != "/" && "$target" != "$USER_HOME" ]] || return 1
    [[ "$(basename -- "$target")" == "nvim" ]] || return 1
}

safe_remove_nvim_path() {
    local target="$1"
    assert_safe_nvim_path "$target" || die "拒绝删除不安全的路径: $target"
    if [[ -e "$target" || -L "$target" ]]; then
        rm -rf -- "$target"
        info "已删除: $target"
    fi
}

safe_remove_staging() {
    local target="${1:-}"
    local parent
    parent="$(dirname -- "$CONF_DIR")"
    [[ -n "$target" && "$target" == "$parent/.nvim-deploy."* ]] || die "拒绝清理不安全的临时目录: $target"
    [[ -e "$target" ]] && rm -rf -- "$target"
}

detect_platform() {
    [[ "$(uname -s)" == "Linux" ]] || die "当前仅支持 Ubuntu、Debian 和 WSL2"
    [[ -r /etc/os-release ]] || die "无法识别 Linux 发行版"

    local distro_id="" distro_like=""
    # shellcheck disable=SC1091
    distro_id="$(. /etc/os-release && printf '%s' "${ID:-}")"
    # shellcheck disable=SC1091
    distro_like="$(. /etc/os-release && printf '%s' "${ID_LIKE:-}")"
    if [[ "$distro_id" != "ubuntu" && "$distro_id" != "debian" && "$distro_like" != *debian* ]]; then
        die "当前仅支持 Ubuntu、Debian 和 WSL2；检测到: ${distro_id:-unknown}"
    fi
}

architecture() {
    case "$(uname -m)" in
        x86_64 | amd64) printf 'x86_64\n' ;;
        aarch64 | arm64) printf 'arm64\n' ;;
        *) die "暂不支持的 CPU 架构: $(uname -m)" ;;
    esac
}

ensure_local_bin_on_path() {
    mkdir -p "$LOCAL_BIN"
    export PATH="$LOCAL_BIN:$PATH"

    local profile="$USER_HOME/.profile"
    local marker="# nvim-deploy local bin"
    if ! grep -Fq "$marker" "$profile" 2>/dev/null; then
        {
            printf '\n%s\n' "$marker"
            # These variables must be expanded by the user's future shell.
            # shellcheck disable=SC2016
            printf 'case ":$PATH:" in\n'
            # shellcheck disable=SC2016
            printf '  *":$HOME/.local/bin:"*) ;;\n'
            # shellcheck disable=SC2016
            printf '  *) export PATH="$HOME/.local/bin:$PATH" ;;\n'
            printf 'esac\n'
        } >>"$profile"
        info "已将 ~/.local/bin 写入 $profile"
    fi
}

download_file() {
    local url="$1"
    local output="$2"
    if command -v curl >/dev/null 2>&1; then
        curl -fL --retry 3 --connect-timeout 15 -o "$output" "$url"
    elif command -v wget >/dev/null 2>&1; then
        wget -O "$output" "$url"
    else
        die "需要 curl 或 wget 才能下载文件"
    fi
}

verify_sha256() {
    local file="$1"
    local expected="$2"
    printf '%s  %s\n' "$expected" "$file" | sha256sum -c - >/dev/null
}

link_local_binary() {
    local source="$1"
    local target="$2"
    mkdir -p "$(dirname -- "$target")"
    if [[ -e "$target" && ! -L "$target" ]]; then
        mv -- "$target" "${target}.bak.$(date +%Y%m%d-%H%M%S)"
        warn "已备份原有命令: $target"
    fi
    ln -sfn -- "$source" "$target"
}

install_system_packages() {
    detect_platform
    local privilege=()
    if ((EUID != 0)); then
        command -v sudo >/dev/null 2>&1 || die "安装系统依赖需要 sudo；也可以从菜单选择【仅安装配置】"
        privilege=(sudo)
    fi

    local packages=(
        ca-certificates curl wget git build-essential cmake ninja-build pkg-config
        unzip tar gzip xz-utils ripgrep fd-find fzf
        python3 python3-venv python3-pip
        imagemagick xclip wl-clipboard default-jdk-headless
    )

    info "正在刷新 apt 软件索引，可能需要输入 sudo 密码"
    "${privilege[@]}" env DEBIAN_FRONTEND=noninteractive apt-get update
    info "正在安装基础、C/C++、Python、Java、图片和搜索工具"
    "${privilege[@]}" env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "${packages[@]}"
}

install_fd_alias() {
    if ! command -v fd >/dev/null 2>&1 && command -v fdfind >/dev/null 2>&1; then
        link_local_binary "$(command -v fdfind)" "$LOCAL_BIN/fd"
        success "已创建 fd -> fdfind 兼容命令"
    fi
}

install_neovim() {
    local current=""
    if command -v nvim >/dev/null 2>&1; then
        current="$(nvim --version | sed -n '1s/^NVIM v//p')"
        if [[ -n "$current" ]] && version_ge "$current" "$MIN_NVIM_VERSION"; then
            success "Neovim $current 已满足要求"
            return 0
        fi
    fi

    local arch asset checksum temp_dir archive extracted target
    arch="$(architecture)"
    asset="nvim-linux-${arch}.tar.gz"
    case "$arch" in
        x86_64) checksum="2fc90b962327f73a78afbfb8203fd19db8db9cdf4ee5e2bef84704339add89cc" ;;
        arm64) checksum="8ddc0c101846145e830b17bbca50782ca9307eee4fab539d9e2ddaf8793c06f1" ;;
    esac

    temp_dir="$(mktemp -d)"
    archive="$temp_dir/$asset"
    extracted="$temp_dir/nvim-linux-${arch}"
    target="$DEPLOY_DATA_DIR/tools/nvim-$NVIM_VERSION-$arch"

    info "正在安装 Neovim $NVIM_VERSION 到用户目录"
    download_file "https://github.com/neovim/neovim/releases/download/v${NVIM_VERSION}/${asset}" "$archive"
    verify_sha256 "$archive" "$checksum" || {
        rm -rf -- "$temp_dir"
        die "Neovim 下载文件校验失败"
    }
    tar -xzf "$archive" -C "$temp_dir"
    mkdir -p "$(dirname -- "$target")"
    if [[ -e "$target" ]]; then
        mv -- "$target" "${target}.bak.$(date +%Y%m%d-%H%M%S)-$$"
        warn "已备份原有 Neovim 安装目录"
    fi
    mv -- "$extracted" "$target"
    link_local_binary "$target/bin/nvim" "$LOCAL_BIN/nvim"
    rm -rf -- "$temp_dir"
    success "Neovim $NVIM_VERSION 安装完成"
}

install_node() {
    local current=""
    if command -v node >/dev/null 2>&1 && command -v npm >/dev/null 2>&1; then
        current="$(node --version | sed 's/^v//')"
        if [[ -n "$current" ]] && version_ge "$current" "$MIN_NODE_VERSION"; then
            success "Node.js $current 已满足要求"
            return 0
        fi
    fi

    local arch node_arch asset checksum temp_dir archive extracted target
    arch="$(architecture)"
    case "$arch" in
        x86_64)
            node_arch="x64"
            checksum="c0649af18e6a24f6fe5535a3e86b341dd49a8e71117c8b68bde973ef834f16f2"
            ;;
        arm64)
            node_arch="arm64"
            checksum="0b2d9f564b6594222a62c82e1df2efe119dd4a4aff29644f4dd325bf360b6bcc"
            ;;
    esac
    asset="node-v${NODE_VERSION}-linux-${node_arch}.tar.xz"
    temp_dir="$(mktemp -d)"
    archive="$temp_dir/$asset"
    extracted="$temp_dir/node-v${NODE_VERSION}-linux-${node_arch}"
    target="$DEPLOY_DATA_DIR/tools/node-$NODE_VERSION-$arch"

    info "正在安装 Node.js $NODE_VERSION 到用户目录"
    download_file "https://nodejs.org/dist/v${NODE_VERSION}/${asset}" "$archive"
    verify_sha256 "$archive" "$checksum" || {
        rm -rf -- "$temp_dir"
        die "Node.js 下载文件校验失败"
    }
    tar -xJf "$archive" -C "$temp_dir"
    mkdir -p "$(dirname -- "$target")"
    if [[ -e "$target" ]]; then
        mv -- "$target" "${target}.bak.$(date +%Y%m%d-%H%M%S)-$$"
        warn "已备份原有 Node.js 安装目录"
    fi
    mv -- "$extracted" "$target"
    link_local_binary "$target/bin/node" "$LOCAL_BIN/node"
    link_local_binary "$target/bin/npm" "$LOCAL_BIN/npm"
    link_local_binary "$target/bin/npx" "$LOCAL_BIN/npx"
    link_local_binary "$target/bin/corepack" "$LOCAL_BIN/corepack"
    rm -rf -- "$temp_dir"
    success "Node.js $NODE_VERSION 安装完成"
}

install_lazygit() {
    if command -v lazygit >/dev/null 2>&1; then
        success "lazygit 已安装"
        return 0
    fi

    local arch asset checksum temp_dir archive target
    arch="$(architecture)"
    asset="lazygit_${LAZYGIT_VERSION}_linux_${arch}.tar.gz"
    case "$arch" in
        x86_64) checksum="f8ea237c41f194cd799b48505518bfdaae4edf5a2ad6bd3d898e939785ee4532" ;;
        arm64) checksum="8b7ca3b344e60340ad1f89f29b9868ee39bcaba5bb92ee818bbe65476bb8b6e7" ;;
    esac

    temp_dir="$(mktemp -d)"
    archive="$temp_dir/$asset"
    target="$DEPLOY_DATA_DIR/tools/lazygit-$LAZYGIT_VERSION-$arch"
    info "正在安装 lazygit $LAZYGIT_VERSION 到用户目录"
    download_file "https://github.com/jesseduffield/lazygit/releases/download/v${LAZYGIT_VERSION}/${asset}" "$archive"
    verify_sha256 "$archive" "$checksum" || {
        rm -rf -- "$temp_dir"
        die "lazygit 下载文件校验失败"
    }
    mkdir -p "$target"
    tar -xzf "$archive" -C "$target" lazygit
    link_local_binary "$target/lazygit" "$LOCAL_BIN/lazygit"
    rm -rf -- "$temp_dir"
    success "lazygit $LAZYGIT_VERSION 安装完成"
}

backup_existing_config() {
    local reason="${1:-install}"
    LAST_BACKUP_DIR=""
    if [[ ! -e "$CONF_DIR" && ! -L "$CONF_DIR" ]]; then
        return 0
    fi

    local timestamp backup_dir
    timestamp="$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$BACKUP_ROOT"
    backup_dir="$(mktemp -d "$BACKUP_ROOT/${timestamp}.XXXXXX")"
    if ! mv -- "$CONF_DIR" "$backup_dir/config"; then
        rmdir -- "$backup_dir" 2>/dev/null || true
        die "无法备份现有配置: $CONF_DIR"
    fi
    {
        printf 'created_at=%s\n' "$(date -Iseconds)"
        printf 'reason=%s\n' "$reason"
        printf 'original_path=%s\n' "$CONF_DIR"
    } >"$backup_dir/metadata"
    LAST_BACKUP_DIR="$backup_dir"
    success "原配置已备份到: $backup_dir"
}

deploy_config() {
    command -v git >/dev/null 2>&1 || die "未找到 git，请先选择【一键安装 / 更新】"

    local config_parent staging candidate previous_backup=""
    config_parent="$(dirname -- "$CONF_DIR")"
    mkdir -p "$config_parent"
    staging="$(mktemp -d "$config_parent/.nvim-deploy.XXXXXX")"
    candidate="$staging/config"

    info "正在从 $REPO_BRANCH 分支下载配置"
    if ! git clone --quiet --filter=blob:none --branch "$REPO_BRANCH" "$REPO_URL" "$candidate"; then
        safe_remove_staging "$staging"
        die "配置下载失败，原配置未发生变化"
    fi
    if [[ ! -f "$candidate/init.lua" ]]; then
        safe_remove_staging "$staging"
        die "下载的仓库缺少 init.lua，拒绝替换现有配置"
    fi

    backup_existing_config "before-install"
    previous_backup="$LAST_BACKUP_DIR"
    if mv -- "$candidate" "$CONF_DIR"; then
        safe_remove_staging "$staging"
        success "Neovim 配置已安装到: $CONF_DIR"
    else
        safe_remove_staging "$staging" || true
        if [[ -n "$previous_backup" && -e "$previous_backup/config" && ! -e "$CONF_DIR" ]]; then
            mv -- "$previous_backup/config" "$CONF_DIR"
            warn "安装失败，已自动恢复原配置"
        fi
        die "无法启用新配置"
    fi
}

latest_backup() {
    [[ -d "$BACKUP_ROOT" ]] || return 1
    local candidate
    while IFS= read -r candidate; do
        if [[ -e "$candidate/config" || -L "$candidate/config" ]]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done < <(find "$BACKUP_ROOT" -mindepth 1 -maxdepth 1 -type d | sort -r)
    return 1
}

restore_latest_backup() {
    local selected current_backup=""
    selected="$(latest_backup)" || die "没有可恢复的配置备份"
    info "准备恢复备份: $selected"

    backup_existing_config "before-restore"
    current_backup="$LAST_BACKUP_DIR"
    mkdir -p "$(dirname -- "$CONF_DIR")"
    if cp -a -- "$selected/config" "$CONF_DIR"; then
        success "配置已恢复；备份副本仍保留在: $selected"
    else
        safe_remove_nvim_path "$CONF_DIR" || true
        if [[ -n "$current_backup" && -e "$current_backup/config" ]]; then
            mv -- "$current_backup/config" "$CONF_DIR"
            warn "恢复失败，已放回操作前的配置"
        fi
        die "配置恢复失败"
    fi
}

resolve_nvim() {
    if command -v nvim >/dev/null 2>&1; then
        command -v nvim
    elif [[ -x "$LOCAL_BIN/nvim" ]]; then
        printf '%s\n' "$LOCAL_BIN/nvim"
    else
        return 1
    fi
}

bootstrap_plugins() {
    local nvim_bin
    if ! nvim_bin="$(resolve_nvim)"; then
        error "未找到 Neovim，请先选择【一键安装 / 更新】"
        return 1
    fi

    info "正在按 lazy-lock.json 安装或恢复插件"
    if ! "$nvim_bin" --headless -u "$CONF_DIR/init.lua" "+Lazy! restore" +qa; then
        error "插件安装或恢复失败"
        return 1
    fi

    if [[ -f "$CONF_DIR/scripts/bootstrap.lua" ]]; then
        info "正在安装 Mason 开发工具"
        if ! "$nvim_bin" --headless -u "$CONF_DIR/init.lua" -l "$CONF_DIR/scripts/bootstrap.lua"; then
            error "Mason 开发工具安装失败"
            return 1
        fi
    fi

    info "正在执行 Neovim 无头启动检查"
    if ! "$nvim_bin" --headless -u "$CONF_DIR/init.lua" +qa; then
        error "Neovim 无头启动检查失败"
        return 1
    fi
    success "插件与开发工具引导完成"
}

rollback_failed_config() {
    local previous_backup="${1:-}"
    if ! safe_remove_nvim_path "$CONF_DIR"; then
        error "自动回滚失败，请从菜单选择【恢复最近一次配置备份】"
        return 1
    fi

    if [[ -n "$previous_backup" && -e "$previous_backup/config" ]]; then
        if ! mv -- "$previous_backup/config" "$CONF_DIR"; then
            error "自动恢复旧配置失败，备份仍位于: $previous_backup"
            return 1
        fi
        warn "插件引导失败，已自动恢复部署前的配置"
    else
        warn "插件引导失败，已移除未完成的新配置"
    fi
}

bootstrap_with_config_rollback() {
    local previous_backup="$LAST_BACKUP_DIR"
    local bootstrap_status=0

    if bootstrap_plugins; then
        return 0
    else
        bootstrap_status=$?
    fi

    rollback_failed_config "$previous_backup" || true
    return "$bootstrap_status"
}

install_claude_code() {
    command -v claude >/dev/null 2>&1 && {
        success "Claude Code CLI 已安装"
        return 0
    }

    local temp_dir installer
    temp_dir="$(mktemp -d)"
    installer="$temp_dir/claude-install.sh"
    info "正在下载 Claude Code 官方安装器"
    download_file "https://claude.ai/install.sh" "$installer"
    bash "$installer"
    rm -rf -- "$temp_dir"
    success "Claude Code CLI 已安装；首次使用仍需执行 claude 完成登录"
}

check_command() {
    local label="$1"
    local command_name="$2"
    local required="${3:-1}"
    if command -v "$command_name" >/dev/null 2>&1; then
        printf '  %s✓%s %-20s %s\n' "$COLOR_GREEN" "$COLOR_RESET" "$label" "$(command -v "$command_name")"
        return 0
    fi

    if ((required == 1)); then
        printf '  %s✗%s %-20s 缺失\n' "$COLOR_RED" "$COLOR_RESET" "$label"
        return 1
    fi
    printf '  %s!%s %-20s 未配置（可选）\n' "$COLOR_YELLOW" "$COLOR_RESET" "$label"
    return 0
}

doctor() {
    local failures=0 nvim_bin="" nvim_version="" git_version=""
    printf '\n%sNeovim 配置环境检查%s\n' "$COLOR_BOLD" "$COLOR_RESET"

    if command -v git >/dev/null 2>&1; then
        git_version="$(git --version | awk '{print $3}')"
        if version_ge "$git_version" 2.19.0; then
            printf '  %s✓%s %-20s %s\n' "$COLOR_GREEN" "$COLOR_RESET" "Git" "$git_version"
        else
            printf '  %s✗%s %-20s %s，要求 >= 2.19.0\n' "$COLOR_RED" "$COLOR_RESET" "Git" "$git_version"
            failures=$((failures + 1))
        fi
    else
        check_command "Git" git || failures=$((failures + 1))
    fi

    if nvim_bin="$(resolve_nvim 2>/dev/null)"; then
        nvim_version="$($nvim_bin --version | sed -n '1s/^NVIM v//p')"
        if [[ -n "$nvim_version" ]] && version_ge "$nvim_version" "$MIN_NVIM_VERSION"; then
            printf '  %s✓%s %-20s %s\n' "$COLOR_GREEN" "$COLOR_RESET" "Neovim" "$nvim_version"
        else
            printf '  %s✗%s %-20s %s，要求 >= %s\n' "$COLOR_RED" "$COLOR_RESET" "Neovim" "${nvim_version:-unknown}" "$MIN_NVIM_VERSION"
            failures=$((failures + 1))
        fi
    else
        printf '  %s✗%s %-20s 缺失\n' "$COLOR_RED" "$COLOR_RESET" "Neovim"
        failures=$((failures + 1))
    fi

    local item
    for item in "ripgrep:rg" "fd:fd" "fzf:fzf" "GCC:gcc" "G++:g++" "Make:make" "CMake:cmake" "Node.js:node" "npm:npm" "Java:java" "ImageMagick:convert" "lazygit:lazygit"; do
        check_command "${item%%:*}" "${item#*:}" || failures=$((failures + 1))
    done
    if ! command -v fd >/dev/null 2>&1 && command -v fdfind >/dev/null 2>&1; then
        warn "系统只有 fdfind；执行完整安装可自动创建 fd 兼容命令"
    fi

    check_command "Claude Code" claude 0
    if command -v xclip >/dev/null 2>&1 || command -v wl-copy >/dev/null 2>&1 || command -v win32yank.exe >/dev/null 2>&1; then
        printf '  %s✓%s %-20s 已找到剪贴板提供程序\n' "$COLOR_GREEN" "$COLOR_RESET" "系统剪贴板"
    else
        printf '  %s!%s %-20s 未找到（复制到系统剪贴板可能不可用）\n' "$COLOR_YELLOW" "$COLOR_RESET" "系统剪贴板"
    fi

    if [[ -f "$CONF_DIR/init.lua" ]]; then
        printf '  %s✓%s %-20s %s\n' "$COLOR_GREEN" "$COLOR_RESET" "配置" "$CONF_DIR"
    else
        printf '  %s✗%s %-20s 未安装\n' "$COLOR_RED" "$COLOR_RESET" "配置"
        failures=$((failures + 1))
    fi

    if [[ -z "${ANTHROPIC_AUTH_TOKEN:-}" ]]; then
        warn "未设置 ANTHROPIC_AUTH_TOKEN；Minuet AI 补全暂不可用"
    fi
    warn "Nerd Font、Claude 登录和终端 Sixel 能力需要在宿主终端中单独确认"

    if ((failures > 0)); then
        error "检查发现 $failures 个必需项缺失"
        return 1
    fi
    success "所有必需项均已就绪"
}

install_config_only() {
    ensure_local_bin_on_path
    install_fd_alias
    deploy_config
    bootstrap_with_config_rollback
}

install_full() {
    install_system_packages
    ensure_local_bin_on_path
    install_fd_alias
    install_neovim
    install_node
    install_lazygit
    deploy_config
    bootstrap_with_config_rollback

    if ! command -v claude >/dev/null 2>&1 && confirm "是否同时安装 Claude Code CLI？"; then
        install_claude_code
    fi

    doctor || true
    printf '\n'
    success "一键部署完成；现在可以直接运行 nvim"
    warn "如果当前终端仍找不到 nvim，请重新打开终端或执行: source ~/.profile"
}

uninstall_config() {
    backup_existing_config "before-uninstall"
    safe_remove_nvim_path "$CONF_DIR"
    safe_remove_nvim_path "$DATA_DIR"
    safe_remove_nvim_path "$STATE_DIR"
    safe_remove_nvim_path "$CACHE_DIR"
    success "Neovim 配置和运行数据已卸载；系统依赖与备份均已保留"
}

print_menu() {
    printf '\n%s我的 Neovim 一键部署%s\n' "$COLOR_BOLD" "$COLOR_RESET"
    printf '  1) 一键安装 / 更新（推荐）\n'
    printf '  2) 仅安装 / 更新配置（环境已准备好）\n'
    printf '  3) 检查当前环境\n'
    printf '  4) 恢复最近一次配置备份\n'
    printf '  5) 卸载配置\n'
    printf '  0) 退出\n\n'
}

interactive_menu() {
    local choice=""
    while true; do
        print_menu
        if ! read_input choice "请选择 [0-5]: "; then
            printf '\n'
            warn "输入已结束"
            return 0
        fi
        case "$choice" in
            1)
                install_full
                pause_menu
                ;;
            2)
                install_config_only
                pause_menu
                ;;
            3)
                doctor || true
                pause_menu
                ;;
            4)
                if confirm "确定恢复最近一次配置备份吗？"; then
                    restore_latest_backup
                fi
                pause_menu
                ;;
            5)
                if confirm "确定卸载配置和 Neovim 运行数据吗？配置会先备份"; then
                    uninstall_config
                fi
                pause_menu
                ;;
            0)
                success "已退出"
                return 0
                ;;
            *) warn "请输入 0 到 5" ;;
        esac
    done
}

print_help() {
    cat <<'EOF'
我的 Neovim 一键部署脚本

最简单的用法（打开交互菜单）：
  bash deploy.sh
  curl -fsSL https://raw.githubusercontent.com/liuzihua699/nvim-config/main/deploy.sh | bash

命令行用法：
  bash deploy.sh menu       打开交互菜单
  bash deploy.sh install    一键安装依赖、配置和插件
  bash deploy.sh config     仅安装配置和插件
  bash deploy.sh doctor     检查环境
  bash deploy.sh restore    恢复最近一次配置备份
  bash deploy.sh uninstall  卸载配置和运行数据

选项：
  -y, --yes                 对危险操作自动确认
  -h, --help                显示帮助

支持范围：Ubuntu、Debian、WSL2（x86_64 / arm64）
EOF
}

main() {
    local action="menu"
    while (($# > 0)); do
        case "$1" in
            menu | install | config | doctor | restore | uninstall) action="$1" ;;
            -y | --yes) ASSUME_YES=1 ;;
            -h | --help)
                print_help
                return 0
                ;;
            *)
                error "未知参数: $1"
                print_help
                return 2
                ;;
        esac
        shift
    done

    case "$action" in
        menu) interactive_menu ;;
        install) install_full ;;
        config) install_config_only ;;
        doctor) doctor ;;
        restore)
            confirm "确定恢复最近一次配置备份吗？" || return 0
            restore_latest_backup
            ;;
        uninstall)
            confirm "确定卸载配置和 Neovim 运行数据吗？配置会先备份" || return 0
            uninstall_config
            ;;
    esac
}

if [[ "${NVIM_DEPLOY_LIBRARY_ONLY:-0}" != "1" ]]; then
    main "$@"
fi
