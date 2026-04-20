-- return {
--   {
--     "princejoogie/chafa.nvim",
--     dependencies = {
--       "nvim-lua/plenary.nvim",
--       "m00qek/baleia.nvim",
--     },
--     opts = {
--       render = {
--         min_padding = 5,
--         show_label = true,
--       },
--       events = {
--         update_on_nvim_resize = true,
--       },
--     },
--   },
-- }

-- return {
--   {
--     "folke/snacks.nvim",
--     opts = {
--       image = {
--         enabled = true,
--         backend = "sixel", -- ← Windows Terminal 用 sixel
--
--         -- 文档内联图片（Markdown 等）
--         doc = {
--           enabled = true,
--           inline = true,
--           float = true,
--         },
--
--         -- 图片转换工具配置
--         convert = {
--           notify = true, -- 转换出错时通知
--         },
--
--         -- 可选：限制最大图片尺寸（单位：终端列/行）
--         max_width = 80,
--         max_height = 40,
--       },
--     },
--   },
-- }
-- return {
--   {
--     "Skardyy/neo-img",
--     build = function()
--       require("neo-img").install()
--     end,
--     opts = {},
--   },
-- }


return {
  {
    "3rd/image.nvim",
    -- ft = { "png", "jpg", "jpeg", "gif", "bmp", "webp", "markdown" },
    ft = { "png", "jpg", "jpeg", "gif", "bmp", "webp" },
    event = "BufReadPre",
    opts = {
      backend = "sixel",
      processor = "magick_cli",
      integrations = {
        markdown = {
          enabled = true,
          resolve_image_path = function(document_path, image_path, fallback)
            -- 支持相对路径：以 md 文件所在目录为基准解析图片路径
            return fallback(document_path, image_path)
          end,
        },
        neorg = { enabled = false },
      },
      editor_only_render_when_focused = true,
      window_overlap_clear_enabled = true,
    },
  },
}
