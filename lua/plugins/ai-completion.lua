return {
  {
    "milanglacier/minuet-ai.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
      vim.api.nvim_set_hl(0, "MinuetVirtualText", { fg = "#808080", italic = true })
      require("minuet").setup({
        provider = "claude",
        provider_options = {
          claude = {
            model = "claude-sonnet-4-6",
            max_tokens = 512,
            api_key = function()
              return os.getenv("ANTHROPIC_AUTH_TOKEN")
            end,
            -- end_point = function ()
            --     return os.getenv("ANTHROPIC_BASE_URL") .. "/v1/messages"
            -- end,
            end_point = "https://code.newcli.com/claude/ultra/v1/messages",
            -- end_point = "https://code.newcli.com/claude/aws/v1/messages",
            -- end_point = "https://code.newcli.com/claude/v1/messages",
          },
        },
        virtualtext = {
          auto_trigger_ft = { "*" },
          keymap = {
            accept = "<C-a>",
            accept_line = "<C-A>",
            next = "<C-n>",
            prev = "<C-p>",
            dismiss = "<C-e>",
          },
        },
        debounce = 600,
      })
    end,
  },
  {
    "saghen/blink.cmp",
    optional = true,
    opts = function(_, opts)
      opts.sources = opts.sources or {}
      opts.sources.default = opts.sources.default or {}
      table.insert(opts.sources.default, "minuet")
      opts.sources.providers = opts.sources.providers or {}
      opts.sources.providers.minuet = {
        name = "minuet",
        module = "minuet.blink",
        score_offset = 8,
        async = true,
      }
    end,
  },
}
