return {
  {
    "danymat/neogen",
    dependencies = "nvim-treesitter/nvim-treesitter",
    config = function()
      require("neogen").setup({
        snippet_engine = "nvim",
        languages = {
          cpp = { template = { annotation_convention = "doxygen" } },
          c = { template = { annotation_convention = "doxygen" } },
        },
      })

      --- 拼接多行函数签名（直到遇见 ; 或 {）
      local function get_signature(bufnr, start_row)
        local max = vim.api.nvim_buf_line_count(bufnr)
        local sig = ""
        for r = start_row, math.min(start_row + 20, max - 1) do
          local l = vim.api.nvim_buf_get_lines(bufnr, r, r + 1, false)[1]
          sig = sig .. " " .. l
          if l:match(";") or l:match("{") then
            break
          end
        end
        return sig
      end

      --- 按逗号拆分参数，但跳过 <> () 内部的逗号
      local function split_params(str)
        local result, depth, cur = {}, 0, ""
        for i = 1, #str do
          local c = str:sub(i, i)
          if c == "<" or c == "(" then
            depth = depth + 1
            cur = cur .. c
          elseif c == ">" or c == ")" then
            depth = depth - 1
            cur = cur .. c
          elseif c == "," and depth == 0 then
            table.insert(result, vim.trim(cur))
            cur = ""
          else
            cur = cur .. c
          end
        end
        if vim.trim(cur) ~= "" then
          table.insert(result, vim.trim(cur))
        end
        return result
      end

      --- 从单个参数声明中提取参数名
      local function extract_param_name(param)
        param = param:gsub("=.*$", "") -- 去掉默认值
        param = vim.trim(param)
        return param:match("([%w_]+)%s*$")
      end

      --- 手动生成 Doxygen 注释（基于正则，不依赖 treesitter）
      local function generate_manual_doxygen(bufnr, row_0)
        local first_line = vim.api.nvim_buf_get_lines(bufnr, row_0, row_0 + 1, false)[1]
        if not first_line then
          return false
        end
        local indent = first_line:match("^(%s*)") or ""

        -- 类/结构体交给 neogen 处理
        if first_line:match("^%s*class%s") or first_line:match("^%s*struct%s") then
          return false
        end

        local sig = get_signature(bufnr, row_0)
        local params_str = sig:match("%((.*)%)")
        if not params_str then
          return false
        end

        -- 判断返回值是否为 void
        local before = sig:match("^(.-)%(")
        local is_void = before and (before:match("%svoid%s") or before:match("^%s*void%s"))

        -- 提取所有参数名
        local param_names = {}
        for _, p in ipairs(split_params(params_str)) do
          local name = extract_param_name(p)
          if name then
            table.insert(param_names, name)
          end
        end

        -- 构建注释行
        local lines = { indent .. "/**", indent .. " * " }
        if #param_names > 0 then
          for _, name in ipairs(param_names) do
            table.insert(lines, indent .. " * @param " .. name .. " ")
          end
        end
        if not is_void then
          table.insert(lines, indent .. " * @return ")
        end
        table.insert(lines, indent .. " */")

        vim.api.nvim_buf_set_lines(bufnr, row_0, row_0, false, lines)

        -- 光标定位到 brief 描述处
        -- vim.api.nvim_win_set_cursor(0, { row_0 + 2, #(indent .. " * ") })
        -- vim.cmd("startinsert!")
        local brief_row = row_0 + 2 -- 1-indexed, " * " 所在行
        vim.api.nvim_win_set_cursor(0, { brief_row, 0 })
        vim.fn.feedkeys(vim.api.nvim_replace_termcodes("A", true, true, true), "n")
        return true
      end

      vim.api.nvim_create_autocmd("FileType", {
        pattern = { "c", "cpp" },
        callback = function(ev)
          vim.keymap.set("i", "<CR>", function()
            local line = vim.api.nvim_get_current_line()

            if line:match("^%s*/%*%*%s*$") then
              local row = vim.api.nvim_win_get_cursor(0)[1] -- 1-indexed
              -- 删掉 /** 这一行
              vim.api.nvim_buf_set_lines(0, row - 1, row, false, {})
              -- 退出插入模式
              local esc = vim.api.nvim_replace_termcodes("<Esc>", true, true, true)
              vim.api.nvim_feedkeys(esc, "n", false)

              vim.schedule(function()
                local target = row - 1 -- 0-indexed，现在指向原来 /** 下方那行
                local target_line = vim.api.nvim_buf_get_lines(0, target, target + 1, false)[1] or ""

                -- 类/结构体 → 用 neogen（treesitter 能正确解析）
                if target_line:match("^%s*class%s") or target_line:match("^%s*struct%s") then
                  vim.api.nvim_win_set_cursor(0, { target + 1, 0 })
                  require("neogen").generate()
                  return
                end

                -- 函数 → 用自定义正则解析（避免宏干扰 treesitter）
                if not generate_manual_doxygen(0, target) then
                  -- 万一也不像函数，兜底用 neogen
                  vim.api.nvim_win_set_cursor(0, { target + 1, 0 })
                  require("neogen").generate()
                end
              end)
              return
            end

            -- ====== 以下是正常 <CR> 行为 ======
            local ok_cmp, cmp = pcall(require, "cmp")
            if ok_cmp and cmp.visible() then
              cmp.confirm({ select = true })
              return
            end
            local ok_blink, blink = pcall(require, "blink.cmp")
            if ok_blink and blink.is_visible and blink.is_visible() then
              blink.accept()
              return
            end
            local cr = vim.api.nvim_replace_termcodes("<CR>", true, true, true)
            vim.api.nvim_feedkeys(cr, "n", false)
          end, { buffer = ev.buf })
        end,
      })
    end,
  },
}
