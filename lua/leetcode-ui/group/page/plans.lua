local study_plan = require("leetcode_ext.study_plan")
local log = require("leetcode.logger")
local cmd = require("leetcode.command")

local Title = require("leetcode-ui.lines.title")
local Button = require("leetcode-ui.lines.button.menu")
local BackButton = require("leetcode-ui.lines.button.menu.back")
local Buttons = require("leetcode-ui.group.buttons.menu")
local Page = require("leetcode-ui.group.page")

local footer = require("leetcode-ui.lines.footer")
local header = require("leetcode-ui.lines.menu-header")

local page = Page()
local buttons = {}

page:insert(header)

page:insert(Title({ "Menu", "Problems" }, "我的题单"))

table.insert(buttons, Button("Top Interview 150", {
  icon = "󰊴",
  sc = "t",
  on_press = function()
    study_plan.open_plan("top-interview-150")
  end,
}))

table.insert(buttons, Button("Refresh Top 150", {
  icon = "󰑐",
  sc = "u",
  on_press = function()
    study_plan.update_plan("top-interview-150")
  end,
}))

table.insert(buttons, Button("刷新我的题单", {
  icon = "󰑐",
  sc = "m",
  on_press = function()
    if study_plan.update_user_favorites() then
      cmd.plan_menu()
    end
  end,
}))

local ok, favorites_or_err = pcall(study_plan.get_user_favorites)
if ok then
  if vim.tbl_isempty(favorites_or_err) then
    table.insert(buttons, Button("暂无我的题单", {
      icon = "󰜌",
      on_press = function()
        log.info("No custom lists were returned by LeetCode")
      end,
    }))
  else
    for _, favorite in ipairs(favorites_or_err) do
      table.insert(buttons, Button(favorite.name, {
        icon = favorite.is_public and "󰖩" or "󰌾",
        on_press = function()
          study_plan.open_user_favorite(favorite.slug)
        end,
      }))
    end
  end
else
  table.insert(buttons, Button("我的题单获取失败", {
    icon = "󰅙",
    on_press = function()
      log.error(favorites_or_err)
    end,
  }))
end

local back = BackButton("problems")

table.insert(buttons, back)

page:insert(Buttons(buttons))

page:insert(footer)

return page
