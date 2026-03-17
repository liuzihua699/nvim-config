return {
  {
    "coder/claudecode.nvim",
    opts = {
      terminal = {
        split_side = "right",
        split_width_percentage = 0.5, -- 占屏幕 50%
      },
    },
    keys = {
      { "<leader>ac", false },
      { "<C-.>", "<cmd>ClaudeCode<cr>", mode = { "n", "t" }, desc = "Toggle Claude" },
    },
  },
}
