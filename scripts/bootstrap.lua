local packages = {
  "clangd",
  "codelldb",
  "debugpy",
  "java-debug-adapter",
  "java-test",
  "jdtls",
  "lua-language-server",
  "markdown-toc",
  "markdownlint-cli2",
  "marksman",
  "prettier",
  "pyright",
  "ruff",
  "shfmt",
  "stylua",
  "tree-sitter-cli",
  "yaml-language-server",
}

local registry = require("mason-registry")
local refresh_finished = false
local refresh_ok = false

registry.refresh(function(ok)
  refresh_ok = ok
  refresh_finished = true
end)

if not vim.wait(120000, function()
  return refresh_finished
end, 100) then
  error("Mason registry refresh timed out")
end

if not refresh_ok then
  error("Mason registry refresh failed")
end

local resolved = {}
local unknown = {}
for _, name in ipairs(packages) do
  local ok, package = pcall(registry.get_package, name)
  if ok then
    resolved[#resolved + 1] = package
  else
    unknown[#unknown + 1] = name
  end
end

if #unknown > 0 then
  error("Unknown Mason packages: " .. table.concat(unknown, ", "))
end

-- LazyVim may already have started some installs while loading the config.
if not vim.wait(900000, function()
  return not vim.iter(resolved):any(function(package)
    return package:is_installing()
  end)
end, 200) then
  error("Existing Mason package installation timed out")
end

local requested = {}
for _, package in ipairs(resolved) do
  if not package:is_installed() then
    requested[#requested + 1] = package.name
    package:install()
  end
end

if #requested > 0 then
  print("Installing Mason packages: " .. table.concat(requested, ", "))
end

if not vim.wait(900000, function()
  return not vim.iter(resolved):any(function(package)
    return package:is_installing()
  end)
end, 200) then
  error("Mason package installation timed out")
end

local failed = vim.iter(resolved)
  :filter(function(package)
    return not package:is_installed()
  end)
  :map(function(package)
    return package.name
  end)
  :totable()

if #failed > 0 then
  error("Failed to install Mason packages: " .. table.concat(failed, ", "))
end

print(("Mason packages ready: %d"):format(#resolved))
