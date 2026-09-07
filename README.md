# My Neovim Config

A personalized Neovim configuration built on [LazyVim](https://github.com/LazyVim/LazyVim), deeply customized for my daily development workflow.

[中文说明](README_CN.md)

## Features

- **Theme**: VSCode Dark
- **Languages**: C/C++ (clangd + CMake) / Python
- **AI**: Claude Code + Minuet AI completion
- **Debugging**: DAP (codelldb) + persistent breakpoints
- **Navigation**: Custom HJKL fast movement, Alt+H/L buffer switching
- **Git**: Inline blame display
- **Image**: Sixel in-terminal image preview
- **Project**: Auto-detect project root, auto-restore session

## Interactive Install

```bash
curl -fsSL https://raw.githubusercontent.com/liuzihua699/nvim-config/main/deploy.sh | bash
```

The command opens an interactive menu for a full install/update, config-only update, environment diagnostics, backup restore, and uninstall.

The recommended option installs Neovim, Git, build tools, CMake, Node.js, Java, search/image/clipboard tools, and lazygit. It then restores the locked plugins and installs the required Mason tools. A `sudo` password may be requested while system packages are installed.

Supported platforms are Ubuntu, Debian, and WSL2 on x86_64 or arm64. A working network connection and Bash are required. AI credentials, Claude login, a Nerd Font, and Sixel terminal support must be configured separately.

For an already cloned repository, run:

```bash
bash deploy.sh
```

Non-interactive subcommands remain available:

```bash
bash deploy.sh install
bash deploy.sh config
bash deploy.sh doctor
bash deploy.sh restore
bash deploy.sh uninstall
```

Configuration backups are stored under `~/.local/state/nvim-deploy/backups/`. Uninstalling keeps system packages, Claude credentials, and these backups.
