-- return {
--   {
--     "folke/snacks.nvim",
--     opts = {
--       explorer = {
--         follow_file = false,
--       },
--     },
--   },
-- }



return {
  {
    "folke/snacks.nvim",
    opts = {
      picker = {
        sources = {
          explorer = {
            follow_file = false,
          },
        },
      },
    },
  },
}
