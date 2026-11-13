local M = {}

local function has_rg()
  if vim.fn.executable("rg") == 1 then
    return true
  end
  vim.notify("MW Dashboard requires ripgrep (rg) for file and content search", vim.log.levels.ERROR)
  return false
end

local function search_options(title, cwd)
  return {
    title = title,
    cwd = cwd or vim.fn.getcwd(),
    hidden = true,
    ignored = false,
    exclude = { ".git" },
    show_empty = true,
    show_delay = 0,
    -- Keep results on the left and the preview on the right, including on smaller screens.
    layout = {
      preset = "default",
      layout = { width = 0.95, height = 0.85, min_width = 0 },
    },
    preview = function(ctx)
      require("snacks.picker.preview").file(ctx)
      -- File sources use a scratch preview; never mark an existing editor buffer read-only.
      if not ctx.item.buf then
        vim.bo[ctx.buf].modifiable = false
        vim.bo[ctx.buf].readonly = true
      end
    end,
  }
end

function M.files(cwd)
  if not has_rg() then
    return
  end
  local opts = search_options("Find files", cwd)
  opts.finder = require("mw-dashboard.sources").files
  opts.supports_live = false
  return require("snacks").picker.files(opts)
end

function M.recent()
  local opts = search_options("Recent files")
  opts.filter = {
    cwd = false,
    filter = function(item)
      local stat = item.file and vim.uv.fs_stat(item.file)
      return stat ~= nil and stat.type == "file"
    end,
  }
  return require("snacks").picker.recent(opts)
end

function M.grep(cwd)
  if not has_rg() then
    return
  end
  local opts = search_options("Search regex", cwd)
  opts.finder = require("mw-dashboard.sources").grep
  opts.live = true
  opts.supports_live = false
  -- Show filenames once, while retaining match locations for previews and Enter.
  opts.format = function(item, picker)
    return require("snacks.picker.format").file({ file = item.file, cwd = item.cwd }, picker)
  end
  return require("snacks").picker(opts)
end

function M.projects(cwd)
  cwd = vim.fs.normalize(cwd or vim.fn.getcwd())
  local ok, err = pcall(vim.api.nvim_set_current_dir, cwd)
  if not ok then
    vim.notify(tostring(err), vim.log.levels.ERROR)
    return
  end
  local function browse(picker, path)
    local changed, change_error = pcall(vim.api.nvim_set_current_dir, path)
    if not changed then
      vim.notify(tostring(change_error), vim.log.levels.ERROR)
      return
    end
    -- Refresh the existing windows so Snacks doesn't restart insert mode on entry.
    picker:set_cwd(path)
    picker.title = "Projects: " .. vim.fn.fnamemodify(path, ":~")
    picker.opts.title = picker.title
    picker.input:set("", "")
    picker.list:set_selected()
    picker.list:set_target(1, 1, { force = true })
    picker:find()
  end
  local function parent(picker)
    local path = vim.fs.dirname(picker:cwd())
    if path and path ~= picker:cwd() then
      browse(picker, path)
    end
  end
  local function search_from_here(picker, open)
    if not has_rg() then
      return
    end
    local path = picker:cwd()
    picker:close()
    vim.schedule(function()
      open(path)
    end)
  end
  return require("snacks").picker({
    title = "Projects: " .. vim.fn.fnamemodify(cwd, ":~"),
    cwd = cwd,
    finder = function(opts, ctx)
      local items = require("mw-dashboard.sources").projects(opts, ctx)
      local parent_path = vim.fs.dirname(ctx:cwd())
      if ctx.filter.search == "" and parent_path and parent_path ~= ctx:cwd() then
        table.insert(items, 1, {
          text = "..",
          file = parent_path,
          dir = true,
          is_parent = true,
        })
      end
      return items
    end,
    live = true,
    supports_live = false,
    format = function(item, picker)
      if item.is_parent then
        return { { "  ..", "SnacksPickerDirectory" } }
      end
      return require("snacks.picker.format").file(item, picker)
    end,
    preview = "none",
    show_empty = true,
    show_delay = 0,
    layout = {
      preset = "select",
      layout = {
        footer = " Enter: open · Backspace: up · Normal: f files, g regex ",
        footer_pos = "center",
      },
    },
    confirm = function(picker, item)
      if not item then
        return
      end
      if item.dir then
        browse(picker, item.file)
      else
        picker:action("jump")
      end
    end,
    actions = {
      project_files = function(picker)
        search_from_here(picker, M.files)
      end,
      project_grep = function(picker)
        search_from_here(picker, M.grep)
      end,
      parent_folder = parent,
      backspace = function(picker)
        if vim.fn.mode():sub(1, 1) == "i" and picker.input:get() ~= "" then
          return "<BS>"
        end
        -- Expression mappings cannot change windows until textlock is released.
        vim.schedule(function()
          parent(picker)
        end)
        return ""
      end,
    },
    win = {
      input = {
        keys = {
          ["f"] = { "project_files", mode = "n", desc = "Find files in this folder" },
          ["g"] = { "project_grep", mode = "n", desc = "Search contents in this folder" },
          ["<BS>"] = {
            "backspace",
            mode = { "n", "i" },
            expr = true,
            desc = "Erase filter or go up",
          },
        },
      },
      list = {
        keys = {
          ["f"] = { "project_files", mode = "n", desc = "Find files in this folder" },
          ["g"] = { "project_grep", mode = "n", desc = "Search contents in this folder" },
          ["<BS>"] = { "parent_folder", desc = "Parent folder" },
        },
      },
    },
  })
end

return M
