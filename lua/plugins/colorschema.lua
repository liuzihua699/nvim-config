return {
  {
    "doums/darcula",
    lazy = true,
  },
  {
    "briones-gabriel/darcula-solid.nvim",
    dependencies = { "rktjmp/lush.nvim" },
    lazy = true,
  },
  {
    "AlexvZyl/nordic.nvim",
    lazy = true,
  },
  {
    "projekt0n/github-nvim-theme",
    lazy = true,
  },
  {
    "rafamadriz/neon",
    lazy = true,
    -- priority = 1000,
    -- config = function()
    --   vim.g.neon_style = "doom" -- "default", "doom", "dark", "light"
    --   vim.g.neon_italic_keyword = true
    --   vim.g.neon_italic_function = true
    --   vim.g.neon_transparent = false
    --   vim.cmd([[colorscheme neon]])
    -- end,
  },
  {
    "Mofiqul/vscode.nvim",
    lazy = false,
    priority = 1000,
    config = function()
      vim.o.background = "dark"
      require("vscode").setup({
        transparent = false,
        italic_comments = true,
        underline_links = true,
        disable_nvimtree_bg = true,
        color_overrides = {},
        group_overrides = {},
      })
      require("vscode").load()
    end,
  },
}
