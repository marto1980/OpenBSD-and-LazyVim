return {
  {
    "L3MON4D3/LuaSnip",
    build = function()
      local make = vim.fn.executable("gmake") == 1 and "gmake" or "make"
      vim.fn.system({ make, "install_jsregexp" })
    end,
  },
}
