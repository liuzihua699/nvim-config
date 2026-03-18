return {
  {
    "danymat/neogen",
    dependencies = "nvim-treesitter/nvim-treesitter",
    config = function()
      require("neogen").setup({
        -- 如果你的 LazyVim 用的是 blink.cmp, 改成 snippet_engine = "nvim"
        snippet_engine = "nvim",
        languages = {
          cpp = { template = { annotation_convention = "doxygen" } },
          c = { template = { annotation_convention = "doxygen" } },
        },
      })

      vim.api.nvim_create_autocmd("FileType", {
        pattern = { "c", "cpp" },
        callback = function(ev)
          vim.keymap.set("i", "<CR>", function()
            local line = vim.api.nvim_get_current_line()

            -- 检测当前行是否为 /**（前后可有空白）
            if line:match("^%s*/%*%*%s*$") then
              local row = vim.api.nvim_win_get_cursor(0)[1]
              -- 删除 /** 这一行，光标自动落到下方的函数/类声明行
              vim.api.nvim_buf_set_lines(0, row - 1, row, false, {})
              -- 退出插入模式
              local esc = vim.api.nvim_replace_termcodes("<Esc>", true, true, true)
              vim.api.nvim_feedkeys(esc, "n", false)
              -- 异步触发 neogen 生成注释
              vim.schedule(function()
                require("neogen").generate()
              end)
              return
            end

            -- ========= 以下为回车的默认行为 =========

            -- 1) 如果补全菜单可见，确认选中项（兼容 nvim-cmp）
            local ok_cmp, cmp = pcall(require, "cmp")
            if ok_cmp and cmp.visible() then
              cmp.confirm({ select = true })
              return
            end

            -- 2) 兼容 blink.cmp（LazyVim 新版默认）
            local ok_blink, blink = pcall(require, "blink.cmp")
            if ok_blink and blink.is_visible and blink.is_visible() then
              blink.accept()
              return
            end

            -- 3) 普通回车
            local cr = vim.api.nvim_replace_termcodes("<CR>", true, true, true)
            vim.api.nvim_feedkeys(cr, "n", false)
          end, { buffer = ev.buf })
        end,
      })
    end,
  },
}
