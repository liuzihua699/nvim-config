local cwd = vim.fn.getcwd()

local function add_lua_path(dir)
  package.path = table.concat({
    dir .. "/?.lua",
    dir .. "/?/init.lua",
    package.path,
  }, ";")
end

add_lua_path(cwd .. "/lua")
add_lua_path(vim.fn.expand("~/.local/share/nvim/lazy/nui.nvim/lua"))
add_lua_path(vim.fn.expand("~/.local/share/nvim/lazy/plenary.nvim/lua"))
add_lua_path(vim.fn.expand("~/.local/share/nvim/lazy/leetcode.nvim/lua"))

local failures = 0
local tests = dofile(cwd .. "/tests/leetcode_study_plan_spec.lua")

for _, test in ipairs(tests) do
  local ok, err = pcall(test.fn)
  if ok then
    print("PASS " .. test.name)
  else
    failures = failures + 1
    print("FAIL " .. test.name)
    print(err)
  end
end

if failures > 0 then
  vim.cmd("cquit " .. failures)
end
