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
              chktex = { onOpenAndSave = true, onEdit = true },
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
      -- This section directly overrides LazyVim's diagnostic defaults
      diagnostics = {
        virtual_text = {
          source = "always", -- Shows source in the line (gutter/end of line)
        },
        float = {
          source = "always", -- Shows source in the hover window (leader + cd)
        },
      },
    },
  },
}
