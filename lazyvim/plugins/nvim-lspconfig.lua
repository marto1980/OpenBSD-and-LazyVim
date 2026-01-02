return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {

        lua_ls = {
          mason = false,
          cmd = { "/usr/local/bin/lua-language-server" },
          settings = {
            Lua = {
              diagnostics = {
                globals = { "vim" },
              },
            },
          },
        },

        texlab = {
          settings = {
            texlab = {
              diagnostics = {
                ignoredPatterns = { "Undefined reference" },
              },
            },
          },
          mason = false,
          cmd = { "/home/marto/.bin/texlab" },
          on_attach = function(client, _)
            client.server_capabilities.documentFormattingProvider = false
            client.server_capabilities.documentRangeFormattingProvider = false
          end,
        },
      },
    },
  },
}
