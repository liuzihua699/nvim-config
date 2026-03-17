-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

vim.g.autoformat = false


vim.api.nvim_create_autocmd("ColorScheme", {
  callback = function()
    vim.api.nvim_set_hl(0, "NeoTreeFileName", { fg = "#CCCCCC" })
    vim.api.nvim_set_hl(0, "NeoTreeDirectoryName", { fg = "#6897BB" })
    vim.api.nvim_set_hl(0, "NeoTreeDirectoryIcon", { fg = "#6897BB" })
    vim.api.nvim_set_hl(0, "NeoTreeNormal", { fg = "#CCCCCC" })
    vim.api.nvim_set_hl(0, "NeoTreeNormalNC", { fg = "#CCCCCC" })
  end,
})



-- 配置terminal颜色
vim.api.nvim_set_hl(0, "CustomDarkBg", { bg = "#141524" })

-- quickfix 窗口（cmake 输出）
vim.api.nvim_create_autocmd("FileType", {
  pattern = "qf",
  callback = function()
    vim.opt_local.winhighlight = "Normal:CustomDarkBg"
  end,
})

-- terminal 窗口
vim.api.nvim_create_autocmd("TermOpen", {
  callback = function()
    vim.opt_local.winhighlight = "Normal:CustomDarkBg"
  end,
})



-- 取消<CR>后的自动注释
vim.api.nvim_create_autocmd("FileType", {
  pattern = "*",
  callback = function()
    vim.opt_local.formatoptions:remove({ "r", "o" })
  end,
})



-- 自动识别项目
vim.api.nvim_create_autocmd("VimEnter", {
  callback = function()
    if vim.fn.argc() > 0 then
      return
    end

    local project_markers = { ".git", "CMakeLists.txt", "Makefile", "package.json" }
    local is_project = false
    for _, marker in ipairs(project_markers) do
      if vim.fn.glob(marker) ~= "" then
        is_project = true
        break
      end
    end

    if is_project then
      require("persistence").load()
    end
  end,
  nested = true,
})
