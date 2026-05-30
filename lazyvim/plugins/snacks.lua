return {
  {
    "folke/snacks.nvim",
    opts = {
      -- Fixes "setup {disabled}" warnings
      statuscolumn = { enabled = true },
      image = { enabled = true }, -- Requires ImageMagick to be installed on OpenBSD
      scroll = { enabled = true },
      words = { enabled = true },
      -- Fixes "vim.ui.input is not set"
      input = { enabled = true },
      -- Fixes "vim.ui.select for Snacks.picker is not enabled"
      picker = {
        enabled = true,
        ui_select = true, -- This specifically hooks into vim.ui.select
      },
    },
    keys = {
      -- Keep your existing default Snacks keymaps here...

      -- ADD THIS: Shortcut to browse your local Maven .m2 dependencies via Snacks
      {
        "<leader>Mm",
        function()
          Snacks.picker.files({
            title = "Local Maven Repository (.m2)",
            cwd = vim.fn.expand("~/.m2/repository"),
          })
        end,
        desc = "Browse Local .m2 Dependencies",
      },
    },
  },
}
