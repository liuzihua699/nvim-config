#!/usr/bin/env bash
set -u

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEPLOY_SCRIPT="$ROOT_DIR/deploy.sh"
FAILURES=0

pass() {
    printf 'PASS %s\n' "$1"
}

fail() {
    printf 'FAIL %s\n%s\n' "$1" "$2"
    FAILURES=$((FAILURES + 1))
}

run_test() {
    local name="$1"
    local fn="$2"
    local output

    if output="$($fn 2>&1)"; then
        pass "$name"
    else
        fail "$name" "$output"
    fi
}

test_shell_syntax() {
    bash -n "$DEPLOY_SCRIPT"
}

test_help_describes_interactive_and_cli_usage() {
    local output
    output="$(bash "$DEPLOY_SCRIPT" --help)"
    [[ "$output" == *"交互菜单"* ]]
    [[ "$output" == *"install"* ]]
    [[ "$output" == *"doctor"* ]]
    [[ "$output" == *"restore"* ]]
}

test_menu_can_exit_from_piped_input() {
    local output
    output="$(printf '0\n' | bash "$DEPLOY_SCRIPT" menu)"
    [[ "$output" == *"一键安装 / 更新"* ]]
    [[ "$output" == *"已退出"* ]]
}

test_menu_stops_when_an_install_action_fails() {
    local output status
    output="$(
        printf '1\n' | NVIM_DEPLOY_LIBRARY_ONLY=1 DEPLOY_SCRIPT="$DEPLOY_SCRIPT" bash -c '
            source "$DEPLOY_SCRIPT"
            install_full() {
                printf "action started\n"
                false
                printf "action continued\n"
            }
            interactive_menu
        ' 2>&1
    )"
    status=$?

    [[ "$status" -ne 0 ]]
    [[ "$output" == *"action started"* ]]
    [[ "$output" != *"action continued"* ]]
}

test_version_comparison() {
    # shellcheck disable=SC1090,SC1091
    NVIM_DEPLOY_LIBRARY_ONLY=1 source "$DEPLOY_SCRIPT"
    version_ge 0.11.6 0.11.2
    version_ge 2.19.0 2.19
    ! version_ge 0.10.4 0.11.2
}

test_xdg_paths_and_safe_delete_guard() {
    local temp_dir
    temp_dir="$(mktemp -d)"
    XDG_CONFIG_HOME="$temp_dir/config" \
        XDG_DATA_HOME="$temp_dir/data" \
        XDG_STATE_HOME="$temp_dir/state" \
        XDG_CACHE_HOME="$temp_dir/cache" \
        NVIM_DEPLOY_LIBRARY_ONLY=1 \
        DEPLOY_SCRIPT="$DEPLOY_SCRIPT" \
        bash -c '
            source "$DEPLOY_SCRIPT"
            [[ "$CONF_DIR" == "$XDG_CONFIG_HOME/nvim" ]]
            [[ "$DATA_DIR" == "$XDG_DATA_HOME/nvim" ]]
            [[ "$STATE_DIR" == "$XDG_STATE_HOME/nvim" ]]
            [[ "$CACHE_DIR" == "$XDG_CACHE_HOME/nvim" ]]
            ! assert_safe_nvim_path "/"
            ! assert_safe_nvim_path "$HOME"
            assert_safe_nvim_path "$CONF_DIR"
        '
    local status=$?
    rm -rf -- "$temp_dir"
    return "$status"
}

test_config_deploy_and_restore_are_transactional() {
    local temp_dir source_repo
    temp_dir="$(mktemp -d)"
    source_repo="$temp_dir/source"
    mkdir -p "$source_repo"
    git -C "$source_repo" init -q -b main
    printf 'return true\n' >"$source_repo/init.lua"
    printf 'new configuration\n' >"$source_repo/deploy-marker"
    git -C "$source_repo" add init.lua deploy-marker
    git -C "$source_repo" -c user.name=tests -c user.email=tests@example.com commit -qm init

    XDG_CONFIG_HOME="$temp_dir/config" \
        XDG_DATA_HOME="$temp_dir/data" \
        XDG_STATE_HOME="$temp_dir/state" \
        XDG_CACHE_HOME="$temp_dir/cache" \
        NVIM_DEPLOY_REPO_URL="$source_repo" \
        NVIM_DEPLOY_LIBRARY_ONLY=1 \
        DEPLOY_SCRIPT="$DEPLOY_SCRIPT" \
        bash -c '
            source "$DEPLOY_SCRIPT"
            mkdir -p "$CONF_DIR"
            printf "old configuration\n" >"$CONF_DIR/old-marker"

            deploy_config
            [[ -f "$CONF_DIR/deploy-marker" ]]
            [[ ! -e "$CONF_DIR/old-marker" ]]
            find "$BACKUP_ROOT" -path "*/config/old-marker" -type f | grep -q .

            restore_latest_backup
            [[ -f "$CONF_DIR/old-marker" ]]
            [[ ! -e "$CONF_DIR/deploy-marker" ]]
            [[ ! -e "$CONF_DIR/nvim" ]]
            [[ "$(find "$BACKUP_ROOT" -mindepth 1 -maxdepth 1 -type d | wc -l)" -eq 2 ]]
            find "$BACKUP_ROOT" -path "*/config/deploy-marker" -type f | grep -q .
        '
    local status=$?
    rm -rf -- "$temp_dir"
    return "$status"
}

test_plugin_failure_restores_previous_config() {
    local temp_dir source_repo
    temp_dir="$(mktemp -d)"
    source_repo="$temp_dir/source"
    mkdir -p "$source_repo"
    git -C "$source_repo" init -q -b main
    printf 'return true\n' >"$source_repo/init.lua"
    printf 'new configuration\n' >"$source_repo/deploy-marker"
    git -C "$source_repo" add init.lua deploy-marker
    git -C "$source_repo" -c user.name=tests -c user.email=tests@example.com commit -qm init

    XDG_CONFIG_HOME="$temp_dir/config" \
        XDG_DATA_HOME="$temp_dir/data" \
        XDG_STATE_HOME="$temp_dir/state" \
        XDG_CACHE_HOME="$temp_dir/cache" \
        NVIM_DEPLOY_REPO_URL="$source_repo" \
        NVIM_DEPLOY_LIBRARY_ONLY=1 \
        DEPLOY_SCRIPT="$DEPLOY_SCRIPT" \
        bash -c '
            source "$DEPLOY_SCRIPT"
            mkdir -p "$CONF_DIR"
            printf "old configuration\n" >"$CONF_DIR/old-marker"

            deploy_config
            bootstrap_plugins() { return 42; }
            if bootstrap_with_config_rollback; then
                exit 1
            fi

            [[ -f "$CONF_DIR/old-marker" ]]
            [[ ! -e "$CONF_DIR/deploy-marker" ]]
        '
    local status=$?
    rm -rf -- "$temp_dir"
    return "$status"
}

run_test "deploy script has valid Bash syntax" test_shell_syntax
run_test "help documents interactive and CLI usage" test_help_describes_interactive_and_cli_usage
run_test "interactive menu exits with piped input" test_menu_can_exit_from_piped_input
run_test "interactive install stops immediately when its action fails" test_menu_stops_when_an_install_action_fails
run_test "version comparison handles Neovim requirements" test_version_comparison
run_test "XDG paths are respected and broad deletes are rejected" test_xdg_paths_and_safe_delete_guard
run_test "configuration deployment and restore are transactional" test_config_deploy_and_restore_are_transactional
run_test "plugin bootstrap failure restores the previous configuration" test_plugin_failure_restores_previous_config

if ((FAILURES > 0)); then
    exit "$FAILURES"
fi
