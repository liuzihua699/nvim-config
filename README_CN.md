# My Neovim Config

基于 [LazyVim](https://github.com/LazyVim/LazyVim) 搭建的个人 Neovim 配置，在 LazyVim 的基础上针对日常开发习惯做了深度定制。

[English](README.md)

## 特性

- **主题**: VSCode Dark
- **语言支持**: C/C++ (clangd + CMake) / Python
- **AI 辅助**: Claude Code + Minuet AI 补全
- **调试**: DAP (codelldb) + 持久化断点
- **导航**: 自定义 HJKL 快速移动，Alt+H/L 切换 Buffer
- **Git**: 行内 blame 显示
- **图片**: Sixel 终端内图片预览
- **项目管理**: 自动识别项目根目录，自动恢复会话

## 一键部署

在 Ubuntu、Debian 或 WSL2 中运行下面一个命令：

```bash
curl -fsSL https://raw.githubusercontent.com/liuzihua699/nvim-config/main/deploy.sh | bash
```

脚本会打开中文交互菜单：

```text
1) 一键安装 / 更新（推荐）
2) 仅安装 / 更新配置（环境已准备好）
3) 检查当前环境
4) 恢复最近一次配置备份
5) 卸载配置
0) 退出
```

推荐选项会安装 Neovim、Git、编译工具、CMake、Node.js、Java、搜索/图片/剪贴板工具和 lazygit，然后恢复锁定版本的插件与 Mason 开发工具。系统软件安装过程中可能需要输入一次 `sudo` 密码。

支持 Ubuntu、Debian、WSL2，以及 x86_64/arm64 架构。运行前只需要可用的网络、`bash`，以及具有 `sudo` 权限的普通用户。AI Token、Claude 登录、Nerd Font 和终端 Sixel 能力需要安装后单独配置。

已下载脚本或已克隆仓库时，也可以直接运行：

```bash
bash deploy.sh
```

## 命令行模式

交互菜单之外，还保留了便于自动化的子命令：

```bash
bash deploy.sh install       # 完整安装
bash deploy.sh config        # 只更新配置和插件
bash deploy.sh doctor        # 环境检查
bash deploy.sh restore       # 恢复最近备份
bash deploy.sh uninstall     # 卸载配置和运行数据
```

安装、恢复和卸载前的原配置会保存在 `~/.local/state/nvim-deploy/backups/`。卸载不会删除系统软件、Claude 登录信息或这些备份。
