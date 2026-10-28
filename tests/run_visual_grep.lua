local cwd = vim.fn.getcwd()
vim.opt.runtimepath:prepend(cwd)
vim.cmd("doautocmd User VeryLazy")

local failures = 0
local tests = dofile(cwd .. "/tests/visual_grep_spec.lua")

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
