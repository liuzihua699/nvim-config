return {
  {
    "Civitasv/cmake-tools.nvim",
    ft = { "c", "cpp", "cmake" },
    dependencies = {
      "nvim-lua/plenary.nvim",
      "mfussenegger/nvim-dap",
    },
    opts = {
      cmake_command = "cmake",
      cmake_build_directory = "build",
      cmake_build_directory_prefix = "build", -- 当parse_build_directory为false时使用
      cmake_generate_options = { "-DCMAKE_EXPORT_COMPILE_COMMANDS=1" },
      cmake_build_options = {},
      cmake_console_size = 10, -- cmake输出窗口高度
      cmake_show_console = "always", -- "always", "only_on_error"
      cmake_dap_configuration = {
        name = "cpp",
        type = "codelldb",
        request = "launch",
        stopOnEntry = false,
        runInTerminal = true,
        console = "integratedTerminal",
      },
      cmake_variants_message = {
        short = { show = true },
        long = { show = true, max_length = 40 },
      },
    },
    -- config = function(_, opts)
    --   require("cmake-tools").setup(opts)
    -- end,
    config = function(_, opts)
      require("cmake-tools").setup(opts)

      vim.api.nvim_create_user_command("CMakeClearCache", function()
        local cache_dir = vim.fn.expand("~") .. "/.cache/cmake_tools_nvim/"
        local cwd = vim.loop.cwd()
        local clean_path = cwd:gsub("/", ""):gsub("\\", ""):gsub(":", "")
        local cache_file = cache_dir .. clean_path .. ".lua"

        if vim.fn.filereadable(cache_file) == 1 then
          os.remove(cache_file)
          vim.notify("已清除 CMake 缓存: " .. cache_file, vim.log.levels.INFO)
        else
          vim.notify("未找到缓存文件: " .. cache_file, vim.log.levels.WARN)
        end
      end, { desc = "清除当前项目的 cmake-tools 缓存" })
    end,
  },
  -- { import = "lazyvim.plugins.extras.lang.clangd" },
  -- { import = "lazyvim.plugins.extras.dap.core" },
}
