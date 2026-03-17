return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      inlay_hints = { enabled = true },
      servers = {
        ["*"] = {
          keys = {
            { "K", false }, -- 禁用 LazyVim 默认的 K = Hover
          },
        },
        clangd = {
          cmd = {
            "clangd",
            "--background-index",
            "--clang-tidy",
            "--header-insertion=never",
            "--completion-style=detailed",
            "--all-scopes-completion",
          },
        },
      },
    },
  },
}
