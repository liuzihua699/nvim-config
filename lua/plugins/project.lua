return {
  {
    "ahmedkhalf/project.nvim",
    config = function()
      require("project_nvim").setup({
        detection_methods = { "pattern" },
        patterns = { ".git" },
        -- show_hidden = true,
        -- scope_chdir = "global",
      })
    end,
  },
  -- {
  --   "folke/snacks.nvim",
  --   opts = function(_, opts)
  --     table.insert(opts.dashboard.preset.keys, 1, {
  --       icon = "󱂵 ",
  --       key = "p",
  --       desc = "Projects",
  --       action = function()
  --         local history = require("project_nvim.utils.history")
  --         local projects = history.get_recent_projects()
  --         vim.ui.select(projects, { prompt = "Select Project:" }, function(choice)
  --           if choice then
  --             vim.cmd("silent! %bdelete!")
  --             vim.cmd("cd " .. choice)
  --             vim.cmd("tcd " .. choice)
  --             pcall(require("persistence").load)
  --           end
  --         end)
  --       end,
  --     })
  --   end,
  -- },
}


-- return {
--
-- }
