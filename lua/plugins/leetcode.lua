return {
  {
    "kawre/leetcode.nvim",
    build = ":TSUpdate html",
    cmd = "Leet",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "MunifTanjim/nui.nvim",
    },
    keys = {
      { "<leader>ll", "<cmd>Leet<cr>", desc = "LeetCode" },
      { "<leader>ld", "<cmd>Leet daily<cr>", desc = "LeetCode Daily" },
      { "<leader>lr", "<cmd>Leet random<cr>", desc = "LeetCode Random" },
    },
    opts = {
      lang = "cpp",
      cn = {
        enabled = true,
        translator = true,
        translate_problems = true,
      },
      storage = {
        home = vim.fn.stdpath("config") .. "/leetcode",
      },
      injector = {
        cpp = {
          imports = function()
            return {
              "#include <bits/stdc++.h>",
            }
          end,
          before = {
            "using namespace std;",
          },
        },
      },
      picker = {
        provider = "snacks-picker",
      },
      plugins = {
        non_standalone = true,
      },
    },
  },
}
