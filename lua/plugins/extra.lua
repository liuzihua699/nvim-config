local function cmake_tools_cache_file()
  local cwd = vim.loop.cwd()
  if not cwd then
    return nil
  end

  local cache_dir = vim.fn.expand("~") .. "/.cache/cmake_tools_nvim/"
  local clean_path = cwd:gsub("/", ""):gsub("\\", ""):gsub(":", "")
  return cache_dir .. clean_path .. ".lua"
end

local function normalize_cmake_tools_session()
  local cache_file = cmake_tools_cache_file()
  if not cache_file or vim.fn.filereadable(cache_file) ~= 1 then
    return
  end

  local ok, session = pcall(dofile, cache_file)
  if not ok or type(session) ~= "table" or next(session) == nil then
    return
  end

  local changed = false
  if type(session.base_settings) ~= "table" then
    session.base_settings = {}
    changed = true
  end
  if type(session.target_settings) ~= "table" then
    session.target_settings = {}
    changed = true
  end
  if type(session.launch_args) == "table" then
    for target in pairs(session.launch_args) do
      if type(session.target_settings[target]) ~= "table" then
        session.target_settings[target] = {}
        changed = true
      end
    end
  end
  if not changed then
    return
  end

  local file = io.open(cache_file, "w")
  if file then
    file:write("return " .. vim.inspect(session))
    file:close()
  end
end

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
      normalize_cmake_tools_session()
      require("cmake-tools").setup(opts)

      vim.api.nvim_create_user_command("CMakeClearCache", function()
        local cache_file = cmake_tools_cache_file()

        if cache_file and vim.fn.filereadable(cache_file) == 1 then
          os.remove(cache_file)
          vim.notify("已清除 CMake 缓存: " .. cache_file, vim.log.levels.INFO)
        else
          vim.notify("未找到缓存文件: " .. tostring(cache_file), vim.log.levels.WARN)
        end
      end, { desc = "清除当前项目的 cmake-tools 缓存" })
    end,
  },
  -- { import = "lazyvim.plugins.extras.lang.clangd" },
  -- { import = "lazyvim.plugins.extras.dap.core" },
}
