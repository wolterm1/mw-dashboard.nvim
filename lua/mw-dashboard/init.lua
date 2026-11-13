local M = {}
-- Capture once during startup, before project browsing changes the working directory.
local startup_directory = vim.fn.getcwd()

local defaults = { fractal = { width = 43, height = 15, iterations = 80 } }
M.config = vim.deepcopy(defaults)

function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", vim.deepcopy(defaults), opts or {})
  for _, name in ipairs({ "width", "height", "iterations" }) do
    local value = M.config.fractal[name]
    assert(
      type(value) == "number" and value >= 1 and value % 1 == 0,
      "fractal." .. name .. " must be a positive integer"
    )
  end
  vim.api.nvim_create_user_command(
    "MWDashboard",
    M.open,
    { desc = "Open the MW dashboard", force = true }
  )
  vim.api.nvim_create_user_command(
    "MWProjects",
    M.projects,
    { desc = "Browse project folders", force = true }
  )
  vim.api.nvim_create_user_command("MWFiles", M.files, { desc = "Find files", force = true })
  vim.api.nvim_create_user_command(
    "MWRecent",
    M.recent,
    { desc = "Find recently opened files", force = true }
  )
  vim.api.nvim_create_user_command(
    "MWGrep",
    M.grep,
    { desc = "Search contents with regex", force = true }
  )
end

-- Pass this table to Snacks' dashboard configuration. It is safe to call before Snacks.setup().
function M.dashboard_opts()
  return require("mw-dashboard.dashboard").options(M.config)
end

function M.open()
  local Snacks = require("snacks")
  -- Use the editor window, so regeneration does not close a floating dashboard.
  return Snacks.dashboard(vim.tbl_extend("force", M.dashboard_opts(), { win = 0 }))
end

function M.projects()
  return require("mw-dashboard.pickers").projects(startup_directory)
end

function M.files()
  return require("mw-dashboard.pickers").files()
end

function M.recent()
  return require("mw-dashboard.pickers").recent()
end

function M.grep()
  return require("mw-dashboard.pickers").grep()
end

return M
