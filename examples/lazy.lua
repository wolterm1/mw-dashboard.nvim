-- Use this as lua/plugins/dashboard.lua in your LazyVim config, replacing the old dashboard spec.
return {
  {
    "folke/snacks.nvim",
    dependencies = {
      {
        dir = vim.fn.expand("~/Code/neovim/nvim-dashboard-mw"),
        name = "mw-dashboard.nvim",
        config = function()
          require("mw-dashboard").setup()
        end,
      },
    },
    opts = function(_, opts)
      opts.dashboard = require("mw-dashboard").dashboard_opts()
    end,
  },
}
