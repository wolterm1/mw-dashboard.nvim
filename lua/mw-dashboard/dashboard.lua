local M = {}
local Julia = require("mw-dashboard.julia")

-- Keep the options neutral; only shortcuts use mw's yellow statement color.
local highlight = "Normal"
local key_highlight = "Statement"
local button_padding = "  "
local icon_gap = "   "
local key_gap = 4
local preferred_button_width = 48

local function button(item, width)
  local label = item.icon .. icon_gap .. item.desc
  local gap = width
    - 2
    - 2 * #button_padding
    - vim.fn.strdisplaywidth(label)
    - vim.fn.strdisplaywidth(item.key)
  item.text = {
    { "│", hl = "NonText" },
    { button_padding, hl = highlight },
    { label .. string.rep(" ", math.max(0, gap)), hl = highlight },
    { item.key, hl = key_highlight },
    { button_padding, hl = highlight },
    { "│", hl = "NonText" },
  }
  item.align = "center"
end

function M.options(config)
  require("mw-dashboard.ui").setup()
  -- Each opened dashboard owns its parameters; resizing never changes the fractal.
  local state, cached, cached_width, cached_height
  local function sections(dashboard)
    local width = math.max(
      1,
      math.min(
        math.max(config.fractal.width, preferred_button_width),
        vim.api.nvim_win_get_width(dashboard.win) - 2
      )
    )
    local fractal_width = math.min(config.fractal.width, width)
    local height = vim.api.nvim_win_get_height(dashboard.win)
    dashboard.opts.width = width
    local actions = {
      {
        key = "p",
        icon = "",
        desc = "Find projects",
        action = function()
          require("mw-dashboard").projects()
        end,
      },
      {
        key = "f",
        icon = "",
        desc = "Find files",
        action = function()
          require("mw-dashboard").files()
        end,
      },
      {
        key = "o",
        icon = "",
        desc = "Recent files",
        action = function()
          require("mw-dashboard").recent()
        end,
      },
      {
        key = "g",
        icon = "",
        desc = "Search regex",
        action = function()
          require("mw-dashboard").grep()
        end,
      },
      {
        key = "r",
        icon = "",
        desc = "New fractal",
        action = function()
          state, cached = nil, nil
          if dashboard.win and vim.api.nvim_win_is_valid(dashboard.win) then
            dashboard:update()
          end
        end,
      },
      { key = "q", icon = "", desc = "Quit", action = ":qa" },
    }
    -- Actions take priority. On tiny windows collapse them into a single legend.
    local compact = height < #actions + 2 or width < 18
    local min_button_width = 0
    for _, action in ipairs(actions) do
      min_button_width = math.max(
        min_button_width,
        vim.fn.strdisplaywidth(action.icon .. icon_gap .. action.desc)
          + vim.fn.strdisplaywidth(action.key)
          + 2
          + 2 * #button_padding
          + key_gap
      )
    end
    local button_width = math.min(width, math.max(preferred_button_width, min_button_width))
    local framed = not compact and width >= min_button_width
    local spacing = not compact and height >= #actions * 2 + 3 and 1 or 0
    local action_height = compact and 1 or #actions + (#actions - 1) * spacing
    local header_padding = math.min(2, math.max(0, height - action_height - 1))
    local header_height = math.max(0, height - action_height - header_padding)
    local items = {}
    if header_height > 0 then
      if not state then
        state = Julia.new(config.fractal.iterations)
      end
      if not cached or cached_width ~= fractal_width or cached_height ~= header_height then
        cached = Julia.render(state, fractal_width, config.fractal.height, header_height)
        cached_width, cached_height = fractal_width, header_height
      end
      items[#items + 1] = { header = cached, padding = header_padding }
    end
    if compact then
      for _, action in ipairs(actions) do
        action.hidden = true
        items[#items + 1] = action
      end
      local separator = width >= #actions * 3 - 2 and "  "
        or width >= #actions * 2 - 1 and " "
        or ""
      local legend = table.concat(
        vim.tbl_map(function(action)
          return action.key
        end, actions),
        separator
      )
      local text = {}
      for char in legend:sub(1, width):gmatch(".") do
        text[#text + 1] = { char, hl = char == " " and highlight or key_highlight }
      end
      items[#items + 1] = {
        text = text,
        align = "center",
      }
    else
      for index, action in ipairs(actions) do
        if framed then
          button(action, button_width)
        else
          local label = action.icon .. " " .. action.desc
          if vim.fn.strdisplaywidth("[" .. action.key .. "] " .. label) > width then
            label = action.desc
          end
          action.text = {
            { "[", hl = highlight },
            { action.key, hl = key_highlight },
            { "] " .. label, hl = highlight },
          }
        end
        action.padding = index < #actions and spacing or 0
      end
      vim.list_extend(items, actions)
    end
    return items
  end
  return {
    enabled = true,
    width = math.max(config.fractal.width, preferred_button_width),
    sections = sections,
  }
end

return M
