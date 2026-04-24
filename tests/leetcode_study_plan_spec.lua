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
    name = "parse_user_favorites extracts remote custom lists with ordered questions",
    fn = function()
      local study_plan = require("leetcode_ext.study_plan")
      local favorites = study_plan.parse_user_favorites(vim.json.decode(read_fixture("problem_list_user_favorites.json")))

      assert_eq(#favorites, 2)
      assert_eq(favorites[1].slug, "0b8xoj1")
      assert_eq(favorites[2].slug, "uSPISoCs")
      assert_eq(favorites[2].name, "速刷-双指针")
      assert_eq(favorites[2].is_public, true)
      assert_list_eq(favorites[2].question_slugs, {
        "partition-list",
        "merge-two-sorted-lists",
      })
    end,
  },
  {
    name = "find_user_favorite returns the matching custom list",
    fn = function()
      local study_plan = require("leetcode_ext.study_plan")
      local favorites = study_plan.parse_user_favorites(vim.json.decode(read_fixture("problem_list_user_favorites.json")))
      local favorite = study_plan.find_user_favorite(favorites, "uSPISoCs")

      assert_eq(favorite.name, "速刷-双指针")
      assert_eq(favorite.slug, "uSPISoCs")
    end,
  },
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
    name = "resolve_questions falls back to official plan metadata when cache entries are missing",
    fn = function()
      local study_plan = require("leetcode_ext.study_plan")
      local config = require("leetcode.config")
      local plan = {
        question_slugs = {
          "is-unique-lcci",
          "check-permutation-lcci",
        },
        groups = {
          {
            questions = {
              {
                title_slug = "is-unique-lcci",
                frontend_id = "面试题 01.01",
                title = "Is Unique LCCI",
                title_cn = "判定字符是否唯一",
                difficulty = "Easy",
                paid_only = false,
              },
              {
                title_slug = "check-permutation-lcci",
                frontend_id = "面试题 01.02",
                title = "Check Permutation LCCI",
                title_cn = "判定是否互为字符重排",
                difficulty = "Easy",
                paid_only = false,
              },
            },
          },
        },
      }

      local selected, missing = study_plan.resolve_questions(plan, {
        {
          title_slug = "check-permutation-lcci",
          frontend_id = "面试题 01.02",
          title = "Check Permutation LCCI",
          title_cn = "判定是否互为字符重排",
          difficulty = "Easy",
          status = "ac",
          ac_rate = 63.2,
          paid_only = false,
          link = "https://leetcode.cn/problems/check-permutation-lcci/",
          topic_tags = {},
        },
      })

      assert_eq(#selected, 2)
      assert_eq(selected[1].title_slug, "is-unique-lcci")
      assert_eq(selected[1].frontend_id, "面试题 01.01")
      assert_eq(selected[1].status, "todo")
      assert_eq(selected[1].ac_rate, 0)
      assert_eq(selected[1].link, ("https://leetcode.%s/problems/is-unique-lcci/"):format(config.domain))
      assert_eq(selected[2].title_slug, "check-permutation-lcci")
      assert_eq(selected[2].status, "ac")
      assert_list_eq(missing, {})
    end,
  },
  {
    name = "extract_my_list_slug preserves case for direct open commands",
    fn = function()
      local study_plan = require("leetcode_ext.study_plan")

      assert_eq(study_plan.extract_my_list_slug("list my open uSPISoCs"), "uSPISoCs")
      assert_eq(study_plan.extract_my_list_slug(" list   my   open   dyCzJ7QS "), "dyCzJ7QS")
      assert_eq(study_plan.extract_my_list_slug("list my"), nil)
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
      assert_eq(type(cmd.plan_update_all), "function")
      assert_eq(type(cmd.commands.list.my), "table")
      assert_eq(type(cmd.commands.list.my[1]), "function")
      assert_eq(type(cmd.commands.list.my.update[1]), "function")
      assert_eq(type(cmd.commands.list.my.open[1]), "function")
    end,
  },
  {
    name = "menu commands target separate official and personal list pages",
    fn = function()
      local study_plan = require("leetcode_ext.study_plan")
      local cmd = require("leetcode.command")
      local opened = {}

      study_plan.setup()

      local orig_set_menu_page = cmd.set_menu_page
      cmd.set_menu_page = function(page)
        table.insert(opened, page)
      end

      cmd.plan_menu()
      cmd.my_list_menu()

      cmd.set_menu_page = orig_set_menu_page

      assert_list_eq(opened, {
        "official_plans",
        "plans",
      })
    end,
  },
  {
    name = "update_all_plans refreshes every configured official plan",
    fn = function()
      local study_plan = require("leetcode_ext.study_plan")
      local refreshed = {}
      local original_plans = study_plan.plans
      local original_update_plan = study_plan.update_plan

      study_plan.plans = {
        ["top-interview-150"] = { name = "Top Interview 150" },
        ["foo-plan"] = { name = "Foo Plan" },
      }
      study_plan.update_plan = function(slug)
        table.insert(refreshed, slug)
      end

      study_plan.update_all_plans()

      study_plan.plans = original_plans
      study_plan.update_plan = original_update_plan

      assert_list_eq(refreshed, {
        "foo-plan",
        "top-interview-150",
      })
    end,
  },
}
