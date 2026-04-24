local study_plan = require("leetcode_ext.study_plan")

local Title = require("leetcode-ui.lines.title")
local Button = require("leetcode-ui.lines.button.menu")
local BackButton = require("leetcode-ui.lines.button.menu.back")
local Buttons = require("leetcode-ui.group.buttons.menu")
local Page = require("leetcode-ui.group.page")

local footer = require("leetcode-ui.lines.footer")
local header = require("leetcode-ui.lines.menu-header")

local page = Page()

page:insert(header)

page:insert(Title({ "Menu", "Problems" }, "Study Plans"))

local top_interview_150 = Button("Top Interview 150", {
  icon = "󰊴",
  sc = "t",
  on_press = function()
    study_plan.open_plan("top-interview-150")
  end,
})

local refresh_top_interview_150 = Button("Refresh Top 150", {
  icon = "󰑐",
  sc = "u",
  on_press = function()
    study_plan.update_plan("top-interview-150")
  end,
})

local back = BackButton("problems")

page:insert(Buttons({
  top_interview_150,
  refresh_top_interview_150,
  back,
}))

page:insert(footer)

return page
