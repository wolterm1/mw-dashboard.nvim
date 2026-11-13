local M = {}
local status_ns = vim.api.nvim_create_namespace("mw-dashboard.search-status")

local function status(ctx, message)
  vim.schedule(function()
    local picker = ctx.picker
    if picker.closed or picker.input.filter.search ~= ctx.filter.search then
      return
    end
    local buf = picker.input.win.buf
    if not buf or not vim.api.nvim_buf_is_valid(buf) then
      return
    end
    vim.api.nvim_buf_clear_namespace(buf, status_ns, 0, -1)
    if message then
      vim.api.nvim_buf_set_extmark(buf, status_ns, 0, 0, {
        virt_text = { { "  " .. message:gsub("\n.*", ""):sub(1, 120), "DiagnosticWarn" } },
        virt_text_pos = "eol",
      })
    end
  end)
end

-- Only scan this level. Resolve symlinks without following a tree recursively.
local function scan(cwd, pattern, include_files)
  local regex
  if pattern and pattern ~= "" then
    local ok, result = pcall(vim.regex, "\\v\\c" .. pattern)
    if not ok then
      return {}, "Invalid name regex"
    end
    regex = result
  end
  local scan, err = vim.uv.fs_scandir(cwd)
  if not scan then
    return {}, err or "Cannot read directory"
  end
  local items = {}
  while true do
    local name, kind = vim.uv.fs_scandir_next(scan)
    if not name then
      break
    end
    if include_files or name:sub(1, 1) ~= "." then
      local path = vim.fs.joinpath(cwd, name)
      if kind == "link" or kind == nil then
        local stat = vim.uv.fs_stat(path)
        kind = stat and stat.type
      end
      local directory = kind == "directory" and name:sub(1, 1) ~= "."
      if
        (directory or (include_files and kind == "file"))
        and (not regex or regex:match_str(name) ~= nil)
      then
        items[#items + 1] = { text = name, file = path, dir = directory }
      end
    end
  end
  table.sort(items, function(a, b)
    if a.dir ~= b.dir then
      return a.dir
    end
    return a.text < b.text
  end)
  return items
end

function M.directories(cwd, pattern)
  return scan(cwd, pattern, false)
end

function M.entries(cwd, pattern)
  return scan(cwd, pattern, true)
end

function M.projects(_, ctx)
  local items, err = M.entries(ctx:cwd(), ctx.filter.search)
  status(ctx, err)
  return items
end

local function json_text(value)
  return value.text or (value.bytes and vim.base64.decode(value.bytes))
end

-- rg emits one match event per matching line. --max-count=1 limits it to the first line per file.
function M.match_item(line, cwd)
  local ok, event = pcall(vim.json.decode, line)
  if not ok or event.type ~= "match" then
    return
  end
  local data = event.data
  local file = json_text(data.path)
  local first = data.submatches[1]
  if not file or not first then
    return
  end
  return {
    text = file,
    file = file,
    cwd = cwd,
    pos = { data.line_number, first.start },
    end_pos = { data.line_number, first["end"] },
  }
end

-- Stream rg output into Snacks and cancel obsolete searches. Exit 1 means no matches.
local function stream(opts, ctx, args, separator, parse)
  status(ctx)
  return function(cb)
    local queue = require("snacks.picker.util.queue").new()
    local task = ctx.async
    local done, aborted, exit_code, stderr = false, false, 0, ""
    local process = vim.system(args, {
      cwd = opts.cwd,
      text = true,
      stdout = function(err, data)
        if aborted then
          return
        end
        if err then
          stderr = tostring(err)
        end
        if data then
          queue:push(data)
        end
        task:resume()
      end,
      stderr = function(_, data)
        if not aborted and data and #stderr < 4096 then
          stderr = stderr .. data
        end
      end,
    }, function(result)
      done, exit_code = true, result.code
      if not aborted then
        task:resume()
      end
    end)
    task:on("abort", function()
      aborted = true
      process:kill(15)
      -- Snacks can replace finder.task during close before this task's done callback runs.
      -- Retain its cancelled state so that callback cannot touch an already-deleted matcher.
      if ctx.picker.closed then
        ctx.picker.finder.task = task
      end
    end)
    local pending = ""
    local function emit(line)
      local item = parse(line, opts.cwd)
      if item then
        cb(item)
      end
    end
    while not done or not queue:empty() do
      if queue:empty() then
        task:suspend()
      else
        pending = pending .. queue:pop()
        local from = 1
        while true do
          local to = pending:find(separator, from, true)
          if not to then
            break
          end
          emit(pending:sub(from, to - 1))
          from = to + 1
        end
        pending = pending:sub(from)
      end
    end
    if pending ~= "" then
      emit(pending)
    end
    if exit_code > 1 then
      status(ctx, stderr ~= "" and vim.trim(stderr) or "Search failed")
    end
  end
end

local function args(opts, flags)
  local ret = { "rg", "--color=never", "--glob=!.git", "--glob=!.bare" }
  vim.list_extend(ret, flags)
  if opts.hidden then
    ret[#ret + 1] = "--hidden"
  end
  if opts.ignored then
    ret[#ret + 1] = "--no-ignore"
  end
  return ret
end

function M.files(opts, ctx)
  return stream(opts, ctx, args(opts, { "--files", "--null" }), "\0", function(file, cwd)
    return { text = file, file = file, cwd = cwd }
  end)
end

function M.grep(opts, ctx)
  if ctx.filter.search == "" then
    status(ctx)
    return {}
  end
  local argv = args(opts, { "--json", "--max-count=1", "--smart-case" })
  -- argv keeps the whole regex out of the shell, including sequences like " -- ".
  vim.list_extend(argv, { "--", ctx.filter.search, "." })
  return stream(opts, ctx, argv, "\n", M.match_item)
end

return M
