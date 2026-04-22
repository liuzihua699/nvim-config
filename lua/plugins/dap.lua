---@diagnostic disable: undefined-global
return {
  {
    "mfussenegger/nvim-dap",
    -- 覆盖 LazyVim 默认的断点快捷键，改用 persistent-breakpoints
    keys = {
      { "<leader>db", function() require("persistent-breakpoints.api").toggle_breakpoint() end, desc = "Toggle Breakpoint" },
      { "<leader>dB", function() require("persistent-breakpoints.api").set_conditional_breakpoint() end, desc = "Conditional Breakpoint" },
      { "<leader>dx", function() require("persistent-breakpoints.api").clear_all_breakpoints() end, desc = "Clear All Breakpoints" },
    },
    config = function()
      local function build_current_cpp()
        local source = vim.api.nvim_buf_get_name(0)
        if source == "" then
          error("Current buffer has no file path")
        end

        local output_dir = vim.fn.stdpath("cache") .. "/leetcode/bin"
        vim.fn.mkdir(output_dir, "p")

        local output = output_dir .. "/" .. vim.fn.fnamemodify(source, ":t:r")
        local result = vim.system({
          "g++",
          "-std=c++20",
          "-g",
          "-O0",
          source,
          "-o",
          output,
        }, { text = true }):wait()

        if result.code ~= 0 then
          error((result.stderr ~= "" and result.stderr) or "Failed to build current file")
        end

        return output
      end

      vim.fn.sign_define("DapBreakpoint", { text = "●", texthl = "DiagnosticError", linehl = "", numhl = "" })
      vim.fn.sign_define("DapBreakpointCondition", { text = "◉", texthl = "DiagnosticWarn", linehl = "", numhl = "" })
      vim.fn.sign_define("DapStopped", { text = "▶", texthl = "DiagnosticOk", linehl = "DapStoppedLine", numhl = "" })

      local dap = require("dap")
      dap.adapters.codelldb = {
        type = "server",
        port = "${port}",
        executable = {
          command = vim.fn.stdpath("data") .. "/mason/bin/codelldb",
          args = { "--port", "${port}" },
        },
      }
      dap.configurations.cpp = {
        {
          name = "LeetCode: Build and Debug Current File",
          type = "codelldb",
          request = "launch",
          program = function()
            return build_current_cpp()
          end,
          cwd = "${fileDirname}",
          args = function()
            local input = vim.fn.input("Args: ")
            if input == "" then return {} end
            return vim.split(input, " ")
          end,
          stopOnEntry = false,
        },
        {
          name = "Launch",
          type = "codelldb",
          request = "launch",
          program = function()
            return vim.fn.input("Path to executable: ", vim.fn.getcwd() .. "/", "file")
          end,
          cwd = "${workspaceFolder}",
          args = function()
            local input = vim.fn.input("Args: ")
            if input == "" then return {} end
            return vim.split(input, " ")
          end,
          stopOnEntry = false,
        },
      }
      dap.configurations.c = dap.configurations.cpp
    end,
  },
  {
    "Weissle/persistent-breakpoints.nvim",
    event = "BufReadPost",
    opts = {
      save_dir = vim.fn.stdpath("data") .. "/persistent_breakpoints",
      load_breakpoints_event = { "BufReadPost" },
    },
  },
}
