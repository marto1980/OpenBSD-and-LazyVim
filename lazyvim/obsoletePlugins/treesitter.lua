return {
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "master", -- CRITICAL: Use the legacy branch for Neorg compatibility
    lazy = false,
    build = ":TSUpdate",
    opts = {
      ensure_installed = { "c", "lua", "vim", "vimdoc", "query", "norg", "norg_meta" },
      auto_install = true,
      highlight = {
        enable = true,
        additional_vim_regex_highlighting = false,
      },
    },
  },
}
