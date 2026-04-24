local curl = require("plenary.curl")
local config = require("leetcode.config")
local log = require("leetcode.logger")

local M = {
  cache_interval = 60 * 60 * 24,
  plans = {
    ["top-interview-150"] = {
      name = "Top Interview 150",
    },
  },
}

local USER_FAVORITES_QUERY = [[
query userFavorites {
  favoritesLists {
    allFavorites {
      idHash
      name
      isPublicFavorite
      questions {
        titleSlug
      }
    }
  }
}
]]

local function plan_url(slug)
  return ("https://leetcode.%s/studyplan/%s/"):format(config.domain, slug)
end

local function plan_cache_file(slug)
  return config.storage.cache:joinpath(("studyplan_%s_%s.json"):format(config.domain, slug))
end

local function favorites_cache_file()
  return config.storage.cache:joinpath(("favorite_lists_%s.json"):format(config.domain))
end

local function find_plan_detail(decoded, slug)
  local queries = (((decoded or {}).props or {}).pageProps or {}).dehydratedState
  queries = queries and queries.queries or {}

  for _, query in ipairs(queries) do
    local detail = (((query or {}).state or {}).data or {}).studyPlanV2Detail
    if detail and detail.slug == slug then
      return detail
    end
  end

  error(("Study plan `%s` not found in page payload"):format(slug))
end

local function normalize_plan(detail)
  local question_slugs = {}
  local groups = {}
  local seen = {}

  for _, group in ipairs(detail.planSubGroups or {}) do
    local questions = {}

    for _, question in ipairs(group.questions or {}) do
      if question.titleSlug and not seen[question.titleSlug] then
        seen[question.titleSlug] = true
        table.insert(question_slugs, question.titleSlug)
      end

      table.insert(questions, {
        title_slug = question.titleSlug,
        frontend_id = question.questionFrontendId,
        title = question.title,
        title_cn = question.translatedTitle,
        difficulty = question.difficulty,
        paid_only = question.paidOnly,
      })
    end

    table.insert(groups, {
      slug = group.slug,
      name = group.name,
      question_num = group.questionNum or #questions,
      questions = questions,
    })
  end

  return {
    slug = detail.slug,
    name = detail.name,
    highlight = detail.highlight,
    question_slugs = question_slugs,
    groups = groups,
  }
end

function M.parse_user_favorites(decoded)
  local all_favorites = (((decoded or {}).data or {}).favoritesLists or {}).allFavorites
  if type(all_favorites) ~= "table" then
    error("Failed to locate favoritesLists.allFavorites in LeetCode response")
  end

  local favorites = {}

  for _, favorite in ipairs(all_favorites) do
    local question_slugs = {}
    local seen = {}

    for _, question in ipairs(favorite.questions or {}) do
      local slug = question.titleSlug
      if slug and not seen[slug] then
        seen[slug] = true
        table.insert(question_slugs, slug)
      end
    end

    table.insert(favorites, {
      slug = favorite.idHash,
      name = favorite.name,
      is_public = favorite.isPublicFavorite and true or false,
      question_slugs = question_slugs,
      question_num = #question_slugs,
      source = "favorite",
    })
  end

  return favorites
end

function M.find_user_favorite(favorites, slug)
  local target = (slug or ""):lower()

  for _, favorite in ipairs(favorites or {}) do
    if type(favorite.slug) == "string" and favorite.slug:lower() == target then
      return favorite
    end
  end

  error(("My list `%s` was not found in your account"):format(slug))
end

function M.extract_my_list_slug(raw_args)
  local trimmed = vim.trim(raw_args or "")
  local slug = trimmed:match("^list%s+my%s+open%s+(.+)$")
  if not slug then
    return
  end

  slug = vim.trim(slug)
  if slug == "" then
    return
  end

  return slug
end

local function decode_plan_cache(contents)
  local ok, payload = pcall(vim.json.decode, contents)
  if ok and payload and payload.plan then
    return payload
  end
end

local function decode_favorites_cache(contents)
  local ok, payload = pcall(vim.json.decode, contents)
  if ok and payload and payload.favorites then
    return payload
  end
end

local function read_cached_plan(slug)
  local file = plan_cache_file(slug)
  if not file:exists() then
    return
  end

  return decode_plan_cache(file:read())
end

local function write_cached_plan(slug, plan)
  local payload = {
    updated_at = os.time(),
    plan = plan,
  }

  plan_cache_file(slug):write(vim.json.encode(payload), "w")
  return payload
end

local function read_cached_favorites()
  local file = favorites_cache_file()
  if not file:exists() then
    return
  end

  return decode_favorites_cache(file:read())
end

local function write_cached_favorites(favorites)
  local payload = {
    updated_at = os.time(),
    favorites = favorites,
  }

  favorites_cache_file():write(vim.json.encode(payload), "w")
  return payload
end

local function fetch_plan_html(slug)
  assert(M.plans[slug], ("Unsupported study plan `%s`"):format(slug))

  local headers = vim.tbl_extend("force", require("leetcode.api.headers").get(), {
    Accept = "text/html,application/xhtml+xml",
  })

  local out = curl.get(plan_url(slug), {
    headers = headers,
    compressed = false,
    retry = 3,
  })

  if out.exit ~= 0 then
    error(("curl failed while fetching study plan `%s`"):format(slug))
  end

  if out.status >= 300 then
    error(("http error %d while fetching study plan `%s`"):format(out.status, slug))
  end

  return out.body
end

function M.extract_next_data_json(html)
  local compact = html:gsub("\r", ""):gsub("\n", "")
  local payload = compact:match('<script id="__NEXT_DATA__" type="application/json">(.-)</script>')
  assert(payload and payload ~= "", "Failed to locate __NEXT_DATA__ payload in study plan page")
  return payload
end

function M.parse_plan_html(html, slug)
  local decoded = vim.json.decode(M.extract_next_data_json(html))
  return normalize_plan(find_plan_detail(decoded, slug))
end

function M.resolve_questions(plan, problems)
  local by_slug = {}
  for _, problem in ipairs(problems or {}) do
    by_slug[problem.title_slug] = problem
  end

  local selected = {}
  local missing = {}

  for _, slug in ipairs(plan.question_slugs or {}) do
    local problem = by_slug[slug]
    if problem then
      table.insert(selected, vim.deepcopy(problem))
    else
      table.insert(missing, slug)
    end
  end

  return selected, missing
end

function M.cached_user_favorites()
  local cached = read_cached_favorites()
  return cached and cached.favorites or {}
end

function M.fetch_plan(slug)
  return M.parse_plan_html(fetch_plan_html(slug), slug)
end

function M.fetch_user_favorites()
  local api_utils = require("leetcode.api.utils")
  local res, err = api_utils.query(USER_FAVORITES_QUERY, {})
  if err then
    error(err.msg or "Failed to fetch LeetCode custom lists")
  end

  return M.parse_user_favorites(res)
end

function M.get_plan(slug, opts)
  opts = opts or {}

  local cached = read_cached_plan(slug)
  local is_fresh = cached
    and cached.updated_at
    and (os.time() - cached.updated_at) <= M.cache_interval

  if cached and not opts.force and is_fresh then
    return cached.plan
  end

  local ok, plan_or_err = pcall(M.fetch_plan, slug)
  if ok then
    return write_cached_plan(slug, plan_or_err).plan
  end

  if cached then
    log.warn(("Failed to refresh study plan `%s`; using cached copy"):format(slug))
    return cached.plan
  end

  error(plan_or_err)
end

function M.get_user_favorites(opts)
  opts = opts or {}

  local cached = read_cached_favorites()
  local is_fresh = cached
    and cached.updated_at
    and (os.time() - cached.updated_at) <= M.cache_interval

  if cached and not opts.force and is_fresh then
    return cached.favorites
  end

  return write_cached_favorites(M.fetch_user_favorites()).favorites
end

function M.get_user_favorite(slug, opts)
  return M.find_user_favorite(M.get_user_favorites(opts), slug)
end

function M.update_plan(slug)
  local ok, plan_or_err = pcall(function()
    return M.get_plan(slug, { force = true })
  end)

  if not ok then
    log.error(plan_or_err)
    return
  end

  log.info(("Study plan `%s` cache updated"):format(slug))
  return plan_or_err
end

function M.update_user_favorites()
  local ok, favorites_or_err = pcall(function()
    return M.get_user_favorites({ force = true })
  end)

  if not ok then
    log.error(favorites_or_err)
    return
  end

  log.info(("My lists cache updated (%d list(s))"):format(#favorites_or_err))
  return favorites_or_err
end

function M.open_plan(slug, opts)
  require("leetcode.utils").auth_guard()

  local ok, err = pcall(function()
    local plan = M.get_plan(slug, opts)
    local selected, missing = M.resolve_questions(plan, require("leetcode.cache.problemlist").get())

    if vim.tbl_isempty(selected) then
      error(("Study plan `%s` did not match any cached questions"):format(slug))
    end

    if not vim.tbl_isempty(missing) then
      log.warn(("Study plan `%s` skipped %d missing question(s)"):format(slug, #missing))
    end

    require("leetcode.picker").question(selected, {})
  end)

  if not ok then
    log.error(err)
  end
end

function M.open_user_favorite(slug, opts)
  require("leetcode.utils").auth_guard()

  local ok, err = pcall(function()
    local favorite = M.get_user_favorite(slug, opts)
    local selected, missing = M.resolve_questions(favorite, require("leetcode.cache.problemlist").get())

    if vim.tbl_isempty(selected) then
      error(("My list `%s` did not match any cached questions"):format(favorite.slug))
    end

    if not vim.tbl_isempty(missing) then
      log.warn(("My list `%s` skipped %d missing question(s)"):format(favorite.slug, #missing))
    end

    require("leetcode.picker").question(selected, {})
  end)

  if not ok then
    log.error(err)
  end
end

local function install_plan_commands()
  local cmd = require("leetcode.command")

  local function reload_page(name)
    package.loaded["leetcode-ui.group.page." .. name] = nil
    cmd.set_menu_page(name)
  end

  cmd.plan_menu = function()
    reload_page("plans")
  end

  cmd.my_list_menu = function()
    reload_page("plans")
  end

  cmd.plan_top_interview_150 = function()
    M.open_plan("top-interview-150")
  end

  cmd.plan_update_top_interview_150 = function()
    M.update_plan("top-interview-150")
  end

  cmd.my_list_open = function(opts)
    local slug = opts and opts.slug and opts.slug[1]
    if not slug or slug == "" then
      log.error("My list slug not provided")
      return
    end

    M.open_user_favorite(slug)
  end

  cmd.my_list_update = function()
    M.update_user_favorites()
  end

  cmd.commands.plan = {
    cmd.plan_menu,
    ["top-interview-150"] = { cmd.plan_top_interview_150 },
    update = {
      cmd.plan_update_top_interview_150,
      ["top-interview-150"] = { cmd.plan_update_top_interview_150 },
    },
  }

  cmd.commands.list.my = {
    cmd.my_list_menu,
    update = { cmd.my_list_update },
    open = {
      cmd.my_list_open,
      _args = {
        slug = {},
      },
    },
  }
end

local function install_startup_command()
  pcall(vim.api.nvim_del_user_command, "Leet")

  vim.api.nvim_create_user_command("Leet", function(args)
    local leetcode = require("leetcode")
    local raw_args = args.args or ""
    local direct_favorite_slug = M.extract_my_list_slug(raw_args)

    if direct_favorite_slug then
      require("leetcode.command").my_list_open({
        slug = { direct_favorite_slug },
      })
      return
    end

    if not (_Lc_state.menu and _Lc_state.menu.bufnr) then
      if not leetcode.start(false) then
        return
      end
    end

    local cmd = require("leetcode.command")
    if args.args ~= "" then
      cmd.exec(args)
    else
      cmd.menu()
    end
  end, {
    bar = true,
    bang = true,
    nargs = "*",
    desc = "Open leetcode.nvim",
    complete = function(_, line)
      local partial = line:match("^Leet%s+list%s+my%s+open%s+([^%s]*)$")
      if partial ~= nil then
        local matches = {}

        for _, favorite in ipairs(M.cached_user_favorites()) do
          if favorite.slug and favorite.slug:find(partial, 1, true) == 1 then
            table.insert(matches, favorite.slug)
          end
        end

        return matches
      end

      return require("leetcode.command").complete(_, line)
    end,
  })
end

function M.setup()
  if M._did_setup then
    return
  end

  M._did_setup = true
  install_plan_commands()
  install_startup_command()
end

return M
