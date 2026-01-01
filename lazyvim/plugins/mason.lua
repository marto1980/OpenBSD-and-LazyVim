return {
  {
    "mason-org/mason.nvim",
    opts = function(_, opts)
      -- This filters out the specific tools LazyVim tries to force-install
      opts.ensure_installed = vim.tbl_filter(function(name)
        return not vim.tbl_contains({ "shfmt", "stylua", "shellcheck" }, name)
      end, opts.ensure_installed or {})
    end,
  },
}
