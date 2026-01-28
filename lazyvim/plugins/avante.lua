return {
  "yetone/avante.nvim",

  -- build on OpenBSD safely
  build = function()
    ---@diagnostic disable-next-line: undefined-field
    local uname = vim.uv.os_uname().sysname
    local plugin_dir = vim.fn.stdpath("data") .. "/lazy/avante.nvim"
    local makefile = plugin_dir .. "/Makefile"
    local local_makefile = plugin_dir .. "/Makefile.local"

    if uname ~= "OpenBSD" then
      vim.fn.system("gmake BUILD_FROM_SOURCE=true")
      return
    end

    local function copy_file(src, dst)
      local infile = io.open(src, "r")
      if not infile then
        return false
      end
      local contents = infile:read("*all")
      infile:close()
      local outfile = io.open(dst, "w")
      if not outfile then
        return false
      end
      outfile:write(contents)
      outfile:close()
      return true
    end

    if not vim.loop.fs_stat(local_makefile) then
      copy_file(makefile, local_makefile)
    end

    local lines, patched, inserted = vim.fn.readfile(local_makefile), {}, false

    for _, l in ipairs(lines) do
      -- When we reach the generic else, insert OpenBSD *before* it
      if l:match("^else$") and not inserted then
        table.insert(patched, "else ifeq ($(UNAME), OpenBSD)")
        table.insert(patched, "\tOS := linux")
        table.insert(patched, "\tEXT := so")
        inserted = true
      end

      table.insert(patched, l)
    end

    vim.fn.writefile(patched, local_makefile)

    -- build
    vim.fn.system({ "sh", "-c", "cd " .. plugin_dir .. " && gmake -f Makefile.local BUILD_FROM_SOURCE=true" })
  end,

  event = "VeryLazy", -- delay loading
  version = false, -- always build from source; -- Never set this value to "*"! Never!
  dependencies = {
    "nvim-lua/plenary.nvim",
    "MunifTanjim/nui.nvim",
    --- The below dependencies are optional,
    "folke/snacks.nvim", -- for input provider snacks
    "nvim-tree/nvim-web-devicons",
    {
      -- support for image pasting
      "HakonHarnes/img-clip.nvim",
      event = "VeryLazy",
      opts = {
        -- recommended settings
        default = {
          embed_image_as_base64 = false,
          prompt_for_file_name = false,
          drag_and_drop = {
            insert_mode = true,
          },
        },
      },
    },
    {
      -- Make sure to set this up properly if you have lazy=true
      "MeanderingProgrammer/render-markdown.nvim",
      opts = {
        file_types = { "markdown", "Avante" },
      },
      ft = { "markdown", "Avante" },
    },
  },

  config = function(_, opts)
    local ok, utils = pcall(require, "avante.utils")
    if ok and utils.get_os_name then
      local orig = utils.get_os_name
      utils.get_os_name = function()
        ---@diagnostic disable-next-line: undefined-field
        if vim.uv.os_uname().sysname == "OpenBSD" then
          return "linux"
        end
        return orig()
      end
    end
    require("avante").setup(opts)
  end,

  keys = {
    {
      "<leader>ap",
      function()
        local avante_config = require("avante.config")
        -- If current provider starts with "gemini", switch to Claude. Otherwise, switch to Gemini Auto.
        if string.find(avante_config.provider, "^gemini") then
          avante_config.provider = "claude-4.5-sonnet"
          avante_config.mode = "legacy"
          vim.notify("Avante: Switched to Claude 4.5 Sonnet (Legacy Mode)", vim.log.levels.INFO, { title = "Avante" })
        else
          avante_config.provider = "gemini-cli"
          avante_config.mode = "agentic"
          vim.notify("Avante: Switched to Gemini Auto (Agentic Mode)", vim.log.levels.WARN, { title = "Avante" })
        end
      end,
      desc = "Avante: Switch Provider (Claude/Gemini-CLI)",
    },
    {
      "<leader>ay",
      function()
        local avante_config = require("avante.config")
        if not string.find(avante_config.provider, "^gemini") then
          vim.notify(
            "Avante: Current provider is not Gemini. Switch to Gemini first (<leader>ap).",
            vim.log.levels.ERROR,
            { title = "Avante" }
          )
          return
        end

        local cycle = {
          ["gemini-cli"] = "gemini-pro",
          ["gemini-pro"] = "gemini-flash",
          ["gemini-flash"] = "gemini-cli",
        }

        local next_provider = cycle[avante_config.provider] or "gemini-cli"
        avante_config.provider = next_provider

        local labels = {
          ["gemini-cli"] = "Gemini Auto (Gemini 3 Preview)",
          ["gemini-pro"] = "Gemini 3 Pro Preview",
          ["gemini-flash"] = "Gemini 3 Flash Preview",
        }

        vim.notify("Avante: Switched to " .. labels[next_provider], vim.log.levels.INFO, { title = "Avante" })
      end,
      desc = "Avante: Cycle Gemini ACP Models",
    },
  },

  opts = function(_, opts)
    -- Disable agentic mode: use legacy mode for manual approval
    -- opts.mode = "legacy"

    -- Default starting model
    opts.provider = "claude-4.5-sonnet"

    opts.behaviour = vim.tbl_extend("force", opts.behaviour or {}, { support_paste_from_clipboard = true })
    opts.timeout = 60000 -- 60 seconds
    local global_extra = { temperature = 0.75 }
    opts.extra_request_body = global_extra

    -- List of models to generate providers dynamically
    local models = {
      -- Core generalist / explanation / documentation
      { "claude-4.5-sonnet", "anthropic/claude-sonnet-4.5" }, -- code refactor / deep reasoning
      { "claude-4.5-opus", "anthropic/claude-opus-4.5" }, -- documentation & architectural writing
      -- Strong programming support
      { "grok-code-fast", "x-ai/grok-code-fast-1" }, -- code completion / autocomplete

      -- Strong generalist baseline
      { "gpt-4.1", "openai/gpt-4.1" }, -- code refactor / deep reasoning

      -- Long‑context / tool usage
      { "gemini-3-flash", "google/gemini-3-flash-preview", { max_tokens = 32768 } }, -- long context editing / large files

      -- Lightweight complement
      { "claude-4.5-haiku", "anthropic/claude-haiku-4.5" }, -- quick hints / drafts / low cost
      { "gpt-4o-mini", "openai/gpt-4o-mini" }, -- quick hints / drafts / low cost
    }

    -- Ensure providers table exists
    opts.providers = opts.providers or {}
    for _, entry in ipairs(models) do
      local name, model, extra = entry[1], entry[2], entry[3]
      local provider = {
        __inherited_from = "openai",
        endpoint = "https://openrouter.ai/api/v1",
        api_key_name = "OPENROUTER_API_KEY",
        model = model,
      }

      -- Merge per-model overrides with global defaults if needed
      provider.extra_request_body = vim.tbl_extend("force", vim.deepcopy(global_extra), extra or {})
      opts.providers[name] = provider
    end

    -- Disable unwanted default providers
    local disabled_providers = { "vertex", "vertex_claude" }
    for _, provider_name in ipairs(disabled_providers) do
      opts.providers[provider_name] = {
        __inherited_from = "openai",
        endpoint = "",
        api_key_name = "DISABLED",
        model = "",
        enabled = false,
      }
    end
    -- ✅ Correctly add ACP providers inside opts
    -- local acp_models = {
    --   { "gemini-cli", "" },
    --   { "gemini-pro", "gemini-3-pro-preview" },
    --   { "gemini-flash", "gemini-3-flash-preview" },
    -- }
    -- for _, entry in ipairs(acp_models) do
    --   local name, model = entry[1], entry[2]
    --   opts.acp_providers[name] = {
    --     command = "gemini",
    --     args = { "--experimental-acp" },
    --     env = {
    --       NODE_NO_WARNINGS = "1",
    --       GEMINI_API_KEY = os.getenv("GEMINI_API_KEY", "--model", model), -- you must set this env variable
    --     },
    --   }
    -- end

    opts.acp_providers = {
      ["gemini-cli"] = {
        command = "gemini",
        args = { "--experimental-acp" },
        env = {
          NODE_NO_WARNINGS = "1",
          GEMINI_API_KEY = os.getenv("GEMINI_API_KEY"), -- you must set this env variable
        },
      },
      ["gemini-pro"] = {
        command = "gemini",
        args = { "--experimental-acp", "--model", "gemini-3-pro-preview" },
        env = {
          NODE_NO_WARNINGS = "1",
          GEMINI_API_KEY = os.getenv("GEMINI_API_KEY"), -- you must set this env variable
        },
      },
      ["gemini-flash"] = {
        command = "gemini",
        args = { "--experimental-acp", "--model", "gemini-3-flash-preview" },
        env = {
          NODE_NO_WARNINGS = "1",
          GEMINI_API_KEY = os.getenv("GEMINI_API_KEY"), -- you must set this env variable
        },
      },
    }
  end,
}
