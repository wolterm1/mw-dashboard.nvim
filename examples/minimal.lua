-- Start with: nvim -u ./examples/minimal.lua
local root = vim.fs.dirname(vim.fs.dirname(debug.getinfo(1, "S").source:sub(2)))
local snacks = vim.env.MW_SNACKS_PATH or (vim.fn.stdpath("data") .. "/lazy/snacks.nvim")
assert(vim.uv.fs_stat(snacks), "Set MW_SNACKS_PATH to an existing snacks.nvim checkout")
vim.opt.rtp:prepend(root)
vim.opt.rtp:prepend(snacks)
vim.opt.swapfile = false
vim.opt.laststatus = 0
vim.opt.showmode = false
require("mw-dashboard").setup()
local colorscheme = vim.fs.joinpath(root, "..", "nvim-color-mw")
if vim.uv.fs_stat(colorscheme) then
  vim.opt.rtp:prepend(colorscheme)
  vim.cmd.colorscheme("mw")
end
require("snacks").setup({
  dashboard = require("mw-dashboard").dashboard_opts(),
  picker = { enabled = true, ui_select = false },
})
