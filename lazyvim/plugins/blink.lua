return {
  "saghen/blink.cmp",
  dependencies = {
    "kaiser-yang/blink-cmp-avante",
  },
  opts = {
    sources = {
      default = { "avante", "lsp", "path", "snippets", "buffer" },
      providers = {
        avante = {
          module = "blink-cmp-avante",
          name = "avante",
          opts = {
            -- options for blink-cmp-avante
          },
        },
      },
    },
  },
}
