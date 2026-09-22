local function assert_eq(actual, expected, message)
  if actual ~= expected then
    error((message or "assert_eq failed") .. ("\nexpected: %s\nactual: %s"):format(vim.inspect(expected), vim.inspect(actual)))
  end
end

return {
  {
    name = "Visual leader slash starts project grep with the selected text",
    fn = function()
      vim.cmd("enew!")
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "query target" })
      vim.api.nvim_win_set_cursor(0, { 1, 0 })

      local captured
      local original_open = LazyVim.pick.open
      LazyVim.pick.open = function(source, opts)
        captured = { source = source, opts = opts }
      end

      local keys = vim.api.nvim_replace_termcodes("vll<Space>/", true, false, true)
      local ok, err = pcall(vim.api.nvim_feedkeys, keys, "xt", false)
      LazyVim.pick.open = original_open

      assert(ok, err)
      assert(captured, "Visual <leader>/ did not start a picker")
      assert_eq(captured.source, "live_grep")
      assert_eq(captured.opts.search, "que")
    end,
  },
}
