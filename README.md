# My Neovim Config

基于 [LazyVim](https://github.com/LazyVim/LazyVim) 搭建的个人 Neovim 配置，在 LazyVim 的基础上针对日常开发习惯做了深度定制。

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

```bash
curl -fsSL https://raw.githubusercontent.com/liuzihua699/nvim-config/main/deploy.sh | bash -s -- install
```

## 卸载

```bash
curl -fsSL https://raw.githubusercontent.com/liuzihua699/nvim-config/main/deploy.sh | bash -s -- uninstall
```
