local M = {}
local initialized = false
local saved
local hidden = { ruler = false, showcmd = false, showmode = false, laststatus = 0 }

local function update()
  local dashboard = vim.bo.filetype == "snacks_dashboard"
  if dashboard then
    -- Neovim restores these window-local options when switching back to an editing buffer.
    vim.opt_local.fillchars:append({ eob = " " })
  end
  -- Keep the dashboard clean underneath its floating search pickers.
  local floating = vim.api.nvim_win_get_config(0).relative ~= ""
  if dashboard or (saved and floating) then
    if not saved then
      saved = {}
      for name in pairs(hidden) do
        saved[name] = vim.o[name]
      end
    end
    for name, value in pairs(hidden) do
      vim.o[name] = value
    end
  elseif saved then
    local original = saved
    saved = nil
    for name, value in pairs(original) do
      -- Preserve settings explicitly changed by the user or another plugin.
      if vim.o[name] == hidden[name] then
        vim.o[name] = value
      end
    end
  end
end

function M.setup()
  if initialized then
    return
  end
  initialized = true
  local group = vim.api.nvim_create_augroup("mw_dashboard_ui", { clear = true })
  vim.api.nvim_create_autocmd({ "BufEnter", "WinEnter" }, {
    group = group,
    callback = update,
  })
  -- Snacks sets its filetype with events disabled, so observe its render event too.
  vim.api.nvim_create_autocmd("User", {
    group = group,
    pattern = "SnacksDashboardUpdatePost",
    callback = update,
  })
  vim.api.nvim_create_autocmd("User", {
    group = group,
    pattern = "SnacksDashboardClosed",
    callback = function()
      vim.schedule(update)
    end,
  })
end

return M
