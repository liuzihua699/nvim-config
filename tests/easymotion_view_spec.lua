local function assert_eq(actual, expected, message)
  if actual ~= expected then
    error((message or "assert_eq failed") .. ("\nexpected: %s\nactual: %s"):format(vim.inspect(expected), vim.inspect(actual)))
  end
end

local function create_offscreen_match_buffer(extra_match)
  vim.cmd("enew!")

  local lines = {}
  for line = 1, 160 do
    lines[line] = ("ordinary line %d"):format(line)
  end
  lines[120] = "offscreen_target()"
  if extra_match then
    lines[122] = "offscreen_target()"
  end

  vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
  vim.api.nvim_win_set_height(0, 12)
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  vim.cmd("normal! zt")
  vim.cmd("clearjumps")
end

return {
  {
    name = "EasyMotion search keeps the offscreen incremental-search viewport after Enter",
    fn = function()
      create_offscreen_match_buffer()

      local keys = vim.api.nvim_replace_termcodes("soffscreen_target<CR>", true, false, true)
      vim.api.nvim_feedkeys(keys, "xt", false)

      assert_eq(vim.api.nvim_win_get_cursor(0)[1], 120, "EasyMotion should land on the offscreen match")
      local view = vim.fn.winsaveview()
      assert(view.topline <= 120 and view.topline + vim.api.nvim_win_get_height(0) > 120, "match should remain visible")
    end,
  },
  {
    name = "EasyMotion search restores the original viewport when cancelled",
    fn = function()
      create_offscreen_match_buffer()
      local original_view = vim.fn.winsaveview()

      local keys = vim.api.nvim_replace_termcodes("soffscreen_target<Esc>", true, false, true)
      vim.api.nvim_feedkeys(keys, "xt", false)

      local view = vim.fn.winsaveview()
      assert_eq(view.lnum, original_view.lnum, "cancel should restore the original cursor line")
      assert_eq(view.topline, original_view.topline, "cancel should restore the original window top line")
    end,
  },
  {
    name = "EasyMotion search records the original location in the jump list",
    fn = function()
      create_offscreen_match_buffer()

      local search_keys = vim.api.nvim_replace_termcodes("soffscreen_target<CR>", true, false, true)
      vim.api.nvim_feedkeys(search_keys, "xt", false)
      assert_eq(vim.api.nvim_win_get_cursor(0)[1], 120)

      local jump_back = vim.api.nvim_replace_termcodes("<C-o>", true, false, true)
      vim.api.nvim_feedkeys(jump_back, "xt", false)
      assert_eq(vim.api.nvim_win_get_cursor(0)[1], 1, "Ctrl-O should return to the location before EasyMotion")
    end,
  },
  {
    name = "EasyMotion search restores the original viewport when target selection is cancelled",
    fn = function()
      create_offscreen_match_buffer(true)
      local original_view = vim.fn.winsaveview()

      local keys = vim.api.nvim_replace_termcodes("soffscreen_target<CR><Esc>", true, false, true)
      vim.api.nvim_feedkeys(keys, "xt", false)

      local view = vim.fn.winsaveview()
      assert_eq(view.lnum, original_view.lnum, "target cancellation should restore the original cursor line")
      assert_eq(view.topline, original_view.topline, "target cancellation should restore the original window top line")
    end,
  },
  {
    name = "EasyMotion search accepts a target in the offscreen match viewport",
    fn = function()
      create_offscreen_match_buffer(true)

      local keys = vim.api.nvim_replace_termcodes("soffscreen_target<CR>2", true, false, true)
      vim.api.nvim_feedkeys(keys, "xt", false)

      assert_eq(vim.api.nvim_win_get_cursor(0)[1], 120, "target key should jump within the offscreen match viewport")
    end,
  },
  {
    name = "EasyMotion search restores the original viewport when there are no matches",
    fn = function()
      create_offscreen_match_buffer()
      local original_view = vim.fn.winsaveview()

      local keys = vim.api.nvim_replace_termcodes("snot_present<CR>", true, false, true)
      vim.api.nvim_feedkeys(keys, "xt", false)

      local view = vim.fn.winsaveview()
      assert_eq(view.lnum, original_view.lnum, "no match should restore the original cursor line")
      assert_eq(view.topline, original_view.topline, "no match should restore the original window top line")
    end,
  },
  {
    name = "EasyMotion search treats Enter without input as cancellation",
    fn = function()
      create_offscreen_match_buffer()
      vim.api.nvim_buf_set_lines(0, 2, 3, false, { "offscreen_target()" })
      local original_view = vim.fn.winsaveview()
      vim.fn.setreg("/", "offscreen_target")

      local keys = vim.api.nvim_replace_termcodes("s<CR>", true, false, true)
      vim.api.nvim_feedkeys(keys, "xt", false)

      local view = vim.fn.winsaveview()
      assert_eq(view.lnum, original_view.lnum, "empty input should not reuse the previous search")
      assert_eq(view.topline, original_view.topline, "empty input should restore the original window top line")
    end,
  },
}
