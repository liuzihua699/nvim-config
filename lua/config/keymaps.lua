-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

local map = vim.keymap.set
local unmap = vim.keymap.del
map("n", "]t", "<cmd>tabnext<cr>", { desc = "Next Tab" })
map("n", "[t", "<cmd>tabprevious<cr>", { desc = "Previous Tab" })

map("n", "<leader>r", function()
  require("mini.bufremove").delete(0, true)
end, { desc = "Close current buffer" })
unmap("n", "<leader>l", { desc = "Lazy" })

vim.keymap.set("n", "<A-h>", "<cmd>bprevious<cr>", { desc = "Previous buffer" })
vim.keymap.set("n", "<A-l>", "<cmd>bnext<cr>", { desc = "Next buffer" })

-- vim.keymap.set({ "n", "v" }, "J", "5j", { desc = "Move down 5 lines" })
-- vim.keymap.set({ "n", "v" }, "K", "5k", { desc = "Move up 5 lines" })
-- vim.keymap.set({ "n", "v" }, "H", "0", { desc = "Go to line start" })
-- vim.keymap.set({ "n", "v" }, "L", "$", { desc = "Go to line end" })

vim.keymap.set({ "n", "v" }, "K", "5k", { desc = "Move up 5 lines" })
vim.keymap.set({ "n", "v" }, "J", "5j", { desc = "Move down 5 lines" })
vim.keymap.set({ "n", "v" }, "H", "0", { desc = "Home" })
vim.keymap.set({ "n", "v" }, "L", "$", { desc = "End" })

-- 覆盖K
vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(args)
    vim.schedule(function()
      if vim.api.nvim_buf_is_valid(args.buf) then
        vim.keymap.set("n", "K", "5k", { buffer = args.buf, desc = "Move up 5 lines" })
        vim.keymap.set("n", "<leader>k", vim.lsp.buf.hover, { buffer = args.buf, desc = "Hover Documentation" })
      end
    end)
  end,
})
vim.keymap.set("n", "<leader>k", vim.lsp.buf.hover, { desc = "Hover Documentation" })


-- 调试相关
vim.keymap.set("n", "<leader>dE", function()
  require("dapui").eval(vim.fn.input("Expression: "))
end, { desc = "Eval Expression" })

vim.keymap.set("n", "<leader>dL", function()
  require("dap").list_breakpoints()
  vim.cmd("copen")
end, { desc = "List all breakpoints" })


-- 快捷进入开始页面
vim.keymap.set("n", "<leader>ls", function() Snacks.dashboard() end, { desc = "Launch Start Screen" })
