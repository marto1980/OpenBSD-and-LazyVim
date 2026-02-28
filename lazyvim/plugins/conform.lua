return {
  {
    "stevearc/conform.nvim",
    opts = function(_, opts)
      -- filetype mappings

      -- map Java to google-java-format
      opts.formatters_by_ft = opts.formatters_by_ft or {}
      opts.formatters_by_ft.java = { "google-java-format" }
      -- tex mappings
      opts.formatters_by_ft.tex = { "tex-fmt" }
      opts.formatters_by_ft.plaintex = { "tex-fmt" }
      opts.formatters_by_ft.latex = { "tex-fmt" }
      -- custom command paths
      opts.formatters = opts.formatters or {}
      opts.formatters["tex-fmt"] = {
        command = os.getenv("HOME") .. "/.cargo/bin/tex-fmt",
      }
      -- Do NOT fall back to LSP formatting
      opts.lsp_fallback = false

      return opts
    end,
  },
}
