return {
  {
    "nvim-neorg/neorg",
    version = "*",
    lazy = false,
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-treesitter/nvim-treesitter",
    },
    opts = {
      load = {
        ["core.defaults"] = {},
        ["core.concealer"] = {},
        ["core.dirman"] = {
          config = {
            workspaces = {
              notes = "~/notes",
            },
            default_workspace = "notes",
          },
        },
        ["core.qol.todo_items"] = {
          config = {
            create_todo_items = true,
            create_todo_parents = true,
            order = {
              { "undone", " " },
              { "done", "x" },
              { "needs_input", "?" },
              { "important", "!" },
              { "urgent", "!!" },
              { "recurring", "+" },
              { "pending", "-" },
              { "on_hold", "=" },
              { "cancelled", "_" },
            },
          },
        },
      },
    },
    keys = {
      {
        "<leader>Rn",
        function()
          vim.cmd("tabnew")
          vim.cmd("Neorg workspace notes")
        end,
        desc = "Neorg notes",
      },
    },
    config = function(_, opts)
      -- Setup Neorg
      require("neorg").setup(opts)

      -- Set fold and conceal defaults
      vim.wo.foldlevel = 99
      vim.wo.conceallevel = 2
    end,
  },
}
