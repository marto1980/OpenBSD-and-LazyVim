return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      -- 1. KILL the default LazyVim ltex setup to stop the "failed to spawn" warning
      setup = {
        ltex = function()
          return true
        end, -- Block LazyVim from launching 'ltex-ls'
      },
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
        ltex_plus = {
          mason = false, -- Prevent Mason from trying to install it
          cmd = { "/home/marto/.bin/ltex-ls-plus" },
          on_attach = function(client, bufnr)
            -- MANUALLY load and setup the extra plugin here
            -- This ensures it ONLY uses your existing ltex_plus client
            require("ltex_extra").setup({
              load_langs = { "en-GB" },
              path = ".ltex",
              server_opts = {
                name = "ltex_plus",
              },
            })
          end,
          -- Additional settings (optional)
          settings = {
            ltex = {
              language = "en-GB",
            },
          },
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
