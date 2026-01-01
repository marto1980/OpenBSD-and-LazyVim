return {
  {
    "mason-org/mason-lspconfig.nvim",
    opts = {
      automatic_enable = {
        exclude = { "lua_ls", "texlab" },
      },
    },
  },
}
