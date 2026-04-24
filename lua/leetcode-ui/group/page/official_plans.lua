local study_plan = require("leetcode_ext.study_plan")
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

page:insert(Title({ "Menu", "Problems" }, "学习计划[官方]"))

for _, plan in ipairs(study_plan.official_plan_entries()) do
  table.insert(buttons, Button(plan.name, {
    icon = "󰊴",
    on_press = function()
      study_plan.open_plan(plan.slug)
    end,
  }))
end

table.insert(buttons, Button("刷新官方题单", {
  icon = "󰑐",
  sc = "u",
  on_press = function()
    if study_plan.update_all_plans() then
      cmd.plan_menu()
    end
  end,
}))

table.insert(buttons, BackButton("problems"))

page:insert(Buttons(buttons))

page:insert(footer)

return page
