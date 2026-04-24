local function read_fixture(name)
  local path = vim.fn.getcwd() .. "/tests/fixtures/" .. name
  return assert(io.open(path, "r")):read("*a")
end

local function assert_eq(actual, expected, message)
  if actual ~= expected then
    error((message or "assert_eq failed") .. ("\nexpected: %s\nactual: %s"):format(vim.inspect(expected), vim.inspect(actual)))
  end
end

local function assert_list_eq(actual, expected, message)
  assert_eq(vim.inspect(actual), vim.inspect(expected), message)
end

return {
  {
    name = "parse_plan_html extracts ordered questions from __NEXT_DATA__",
    fn = function()
      local study_plan = require("leetcode_ext.study_plan")
      local plan = study_plan.parse_plan_html(read_fixture("studyplan_top_interview_150.html"), "top-interview-150")

      assert_eq(plan.slug, "top-interview-150")
      assert_eq(plan.name, "Top Interview 150")
      assert_eq(#plan.groups, 2)
      assert_list_eq(plan.question_slugs, {
        "merge-sorted-array",
        "remove-element",
        "ransom-note",
      })
    end,
  },
  {
    name = "resolve_questions preserves plan order and reports missing slugs",
    fn = function()
      local study_plan = require("leetcode_ext.study_plan")
      local plan = {
        question_slugs = {
          "remove-element",
          "missing-problem",
          "merge-sorted-array",
        },
      }

      local selected, missing = study_plan.resolve_questions(plan, {
        { title_slug = "merge-sorted-array", frontend_id = "88", title = "Merge Sorted Array" },
        { title_slug = "remove-element", frontend_id = "27", title = "Remove Element" },
      })

      assert_eq(#selected, 2)
      assert_eq(selected[1].title_slug, "remove-element")
      assert_eq(selected[2].title_slug, "merge-sorted-array")
      assert_list_eq(missing, { "missing-problem" })
    end,
  },
  {
    name = "setup injects the plan command tree",
    fn = function()
      local study_plan = require("leetcode_ext.study_plan")
      local cmd = require("leetcode.command")

      study_plan.setup()

      assert_eq(type(cmd.commands.plan), "table")
      assert_eq(type(cmd.commands.plan[1]), "function")
      assert_eq(type(cmd.commands.plan["top-interview-150"][1]), "function")
      assert_eq(type(cmd.commands.plan.update[1]), "function")
    end,
  },
}
