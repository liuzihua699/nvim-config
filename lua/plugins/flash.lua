return {
  {
    "folke/flash.nvim",
    enabled = false,
  },
  {
    "easymotion/vim-easymotion",
    init = function()
      vim.g.EasyMotion_do_mapping = 0
      vim.g.EasyMotion_keys = "234hkjl"
      vim.g.EasyMotion_use_upper = 0
      vim.g.EasyMotion_smartcase = 1
      vim.g.EasyMotion_grouping = 1
    end,
    config = function()
      local opts = { remap = true, silent = true }
      local suspended_lsp_clients = {}

      local easymotion_lsp_group = vim.api.nvim_create_augroup("easymotion_lsp_suspend", { clear = true })

      vim.api.nvim_create_autocmd("User", {
        group = easymotion_lsp_group,
        pattern = "EasyMotionPromptBegin",
        callback = function(args)
          local bufnr = args.buf
          if suspended_lsp_clients[bufnr] then
            return
          end

          local client_ids = {}
          for _, client in ipairs(vim.lsp.get_clients({ bufnr = bufnr })) do
            client_ids[#client_ids + 1] = client.id
          end
          suspended_lsp_clients[bufnr] = client_ids

          -- vim-easymotion temporarily writes its labels into the buffer.
          -- Detach LSP clients so they never parse that short-lived text.
          for _, client_id in ipairs(client_ids) do
            vim.lsp.buf_detach_client(bufnr, client_id)
          end
        end,
      })

      vim.api.nvim_create_autocmd("User", {
        group = easymotion_lsp_group,
        pattern = "EasyMotionPromptEnd",
        callback = function(args)
          local bufnr = args.buf
          local client_ids = suspended_lsp_clients[bufnr]
          suspended_lsp_clients[bufnr] = nil
          if not client_ids then
            return
          end

          -- EasyMotionPromptEnd runs after the original lines are restored.
          -- Reattaching sends the clean buffer contents to each LSP client.
          for _, client_id in ipairs(client_ids) do
            if vim.lsp.get_client_by_id(client_id) then
              vim.lsp.buf_attach_client(bufnr, client_id)
            end
          end
        end,
      })

      local function easymotion_search()
        local original_view = vim.fn.winsaveview()
        local input = vim.fn["EasyMotion#command_line#GetInput"](-1, "", 2)
        if input == nil or input == "" then
          vim.fn.winrestview(original_view)
          return
        end

        local pattern = input
        if vim.g.EasyMotion_use_regexp ~= 1 then
          pattern = vim.fn.escape(input, ".$^~\\[]*")
          if pattern == " " then
            pattern = "\\s\\+"
          end
        end

        local case_flag = vim.fn["EasyMotion#helper#should_case_sensitive"](input, 1) == 1 and "\\c" or "\\C"
        pattern = case_flag .. pattern

        if vim.g.EasyMotion_add_search_history ~= 0 then
          local history_pattern = pattern:gsub("\\c", ""):gsub("\\C", "")
          vim.fn.setreg("/", history_pattern)
          vim.fn.histadd("search", history_pattern)
        end

        local cancelled = vim.fn["EasyMotion#go"]({
          pattern = pattern,
          direction = 2,
          accept_cursor_pos = true,
        })
        if cancelled ~= 0 then
          vim.fn.winrestview(original_view)
          return
        end

        local destination_view = vim.fn.winsaveview()
        vim.fn.winrestview(original_view)
        vim.cmd("normal! m`")
        vim.fn.winrestview(destination_view)
      end

      vim.keymap.set("n", "s", easymotion_search, {
        silent = true,
        desc = "EasyMotion Search",
      })
      vim.keymap.set({ "x", "o" }, "s", "<Plug>(easymotion-sn)", vim.tbl_extend("force", opts, {
        desc = "EasyMotion Search",
      }))
      vim.keymap.set("n", "f", "<Plug>(easymotion-overwin-f)", vim.tbl_extend("force", opts, {
        desc = "EasyMotion Find",
      }))
      vim.keymap.set({ "x", "o" }, "f", "<Plug>(easymotion-bd-f)", vim.tbl_extend("force", opts, {
        desc = "EasyMotion Find",
      }))
    end,
  },
}
