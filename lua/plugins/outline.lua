return {
  {
    "hedyhli/outline.nvim",
    opts = {
      keymaps = {
        up_and_jump = { "k", "<Up>" },
        down_and_jump = { "j", "<Down>" },
      },
      symbols = {
        filter = {
          python = false,
          cpp = false,
          yaml = false,
        },
      },
    },
  },
}
