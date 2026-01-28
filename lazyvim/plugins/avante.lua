-- Constants
local OPENBSD = "OpenBSD"
local OPENROUTER_ENDPOINT = "https://openrouter.ai/api/v1"
local DEFAULT_TIMEOUT_MS = 60000 -- 60 seconds for longer generation tasks
local DEFAULT_TEMPERATURE = 0.75 -- Balanced between creativity and consistency

return {
  "yetone/avante.nvim",

  -- Build function with special handling for OpenBSD
  -- Non-OpenBSD systems: standard gmake build
  -- OpenBSD systems: patch Makefile to recognize OpenBSD, then build
  build = function()
    ---@diagnostic disable-next-line: undefined-field
    local uname = vim.uv.os_uname().sysname
    local plugin_dir = vim.fn.stdpath("data") .. "/lazy/avante.nvim"
    local makefile = plugin_dir .. "/Makefile"
    local local_makefile = plugin_dir .. "/Makefile.local"

    -- Non-OpenBSD systems: use standard build process
    if uname ~= OPENBSD then
      local result = vim.fn.system("gmake BUILD_FROM_SOURCE=true")
      if vim.v.shell_error ~= 0 then
        vim.notify("Avante build failed: " .. result, vim.log.levels.ERROR)
      end
      return
    end

    local function copy_file(src, dst)
      local infile = io.open(src, "r")
      if not infile then
        return false, "Failed to open source file: " .. src
      end
      local contents = infile:read("*all")
      infile:close()
      local outfile = io.open(dst, "w")
      if not outfile then
        return false, "Failed to open destination file: " .. dst
      end
      outfile:write(contents)
      outfile:close()
      return true
    end

    -- OpenBSD: Copy and patch Makefile to recognize OpenBSD as a valid platform
    if not vim.uv.fs_stat(local_makefile) then
      local success, err = copy_file(makefile, local_makefile)
      if not success then
        vim.notify("Avante: " .. err, vim.log.levels.ERROR)
        return
      end
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

    -- Build using the patched Makefile
    local result = vim.fn.system({
      "sh",
      "-c",
      "cd " .. plugin_dir .. " && gmake -f Makefile.local BUILD_FROM_SOURCE=true",
    })
    if vim.v.shell_error ~= 0 then
      vim.notify("Avante OpenBSD build failed: " .. result, vim.log.levels.ERROR)
    end
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
    -- Monkey-patch avante.utils.get_os_name to report OpenBSD as "linux"
    -- This ensures the plugin uses Linux-compatible binaries on OpenBSD
    local ok, utils = pcall(require, "avante.utils")
    if ok and utils.get_os_name then
      local orig = utils.get_os_name
      utils.get_os_name = function()
        ---@diagnostic disable-next-line: undefined-field
        if vim.uv.os_uname().sysname == OPENBSD then
          return "linux"
        end
        return orig()
      end
    end

    -- 🔧 PATCH: guard against nil message.content (OpenRouter / ACP bug)
    do
      local ok_openai, openai = pcall(require, "avante.providers.openai")
      if ok_openai and type(openai.parse_messages) == "function" then
        local orig = openai.parse_messages
        openai.parse_messages = function(...)
          local messages = orig(...)
          for _, m in ipairs(messages) do
            if m.content == nil then
              m.content = ""
            end
          end
          return messages
        end
      end
    end

    require("avante").setup(opts)
  end,

  keys = {
    {
      "<leader>am",
      function()
        local avante_config = require("avante.config")
        local snacks = require("snacks")

        -- Define all available providers with descriptions
        local providers = {
          { name = "claude-4.5-sonnet", desc = "Claude 4.5 Sonnet (Legacy)", mode = "legacy" },
          { name = "claude-4.5-opus", desc = "Claude 4.5 Opus (Legacy)", mode = "legacy" },
          { name = "gemini-cli", desc = "Gemini Auto (Agentic)", mode = "agentic" },
          { name = "gemini-pro", desc = "Gemini 3 Pro Preview (Agentic)", mode = "agentic" },
          { name = "gemini-flash", desc = "Gemini 3 Flash Preview (Agentic)", mode = "agentic" },
          { name = "grok-code-fast", desc = "Grok Code Fast (Legacy)", mode = "legacy" },
          { name = "gpt-4.1", desc = "GPT-4.1 (Legacy)", mode = "legacy" },
          { name = "gemini-3-flash", desc = "Gemini 3 Flash (Legacy)", mode = "legacy" },
          { name = "claude-4.5-haiku", desc = "Claude 4.5 Haiku (Legacy)", mode = "legacy" },
          { name = "gpt-4o-mini", desc = "GPT-4o Mini (Legacy)", mode = "legacy" },
        }

        -- Format items for the picker with visual indicator for current provider
        local current_provider = avante_config.provider
        local items = {}
        for _, p in ipairs(providers) do
          local indicator = (p.name == current_provider) and "● " or "  "
          table.insert(items, {
            text = string.format("%s%-25s %s", indicator, p.name, p.desc),
            provider = p.name,
            mode = p.mode,
          })
        end

        -- Show picker with correct format
        snacks.picker.pick({
          items = items,
          prompt = "Select Avante Provider",
          format = "text", -- Use the built-in "text" formatter
          layout = {
            preset = "select", -- Use select layout which has no preview
          },
          confirm = function(picker, item)
            picker:close()
            if item then
              avante_config.provider = item.provider
              avante_config.mode = item.mode
              vim.notify(
                string.format("Switched to %s (%s mode)", item.provider, item.mode),
                vim.log.levels.INFO,
                { title = "Avante" }
              )
            end
          end,
        })
      end,
      desc = "Avante: Switch Provider (Claude/Gemini-CLI)",
    },
  },

  opts = function(_, opts)
    -- Disable agentic mode: use legacy mode for manual approval
    -- opts.mode = "legacy"

    -- Default starting model
    opts.provider = "claude-4.5-sonnet"

    opts.behaviour = vim.tbl_extend("force", opts.behaviour or {}, { support_paste_from_clipboard = true })
    opts.timeout = DEFAULT_TIMEOUT_MS
    -- Global request body settings applied to all providers
    -- Temperature controls randomness: 0=deterministic, 1=creative, 0.75=balanced
    local global_extra = { temperature = DEFAULT_TEMPERATURE }
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

    -- Generate OpenRouter providers dynamically from the models list
    opts.providers = opts.providers or {}
    for _, entry in ipairs(models) do
      local name, model, extra = entry[1], entry[2], entry[3]
      local provider = {
        __inherited_from = "openai",
        endpoint = OPENROUTER_ENDPOINT,
        api_key_name = "OPENROUTER_API_KEY",
        model = model,
      }

      -- Merge per-model overrides with global defaults if needed
      provider.extra_request_body = vim.tbl_extend("force", vim.deepcopy(global_extra), extra or {})
      opts.providers[name] = provider
    end

    -- Disable unwanted default providers
    local disabled_providers = { "vertex", "vertex_claude", "gemini", "anthropic" }
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
    local acp_models = {
      { "gemini-cli", "" },
      { "gemini-pro", "gemini-3-pro-preview" },
      { "gemini-flash", "gemini-3-flash-preview" },
    }
    opts.acp_providers = opts.acp_providers or {}
    for _, entry in ipairs(acp_models) do
      local name, model = entry[1], entry[2]
      local args = { "--experimental-acp" }
      if model ~= "" then
        table.insert(args, "--model")
        table.insert(args, model)
      end

      opts.acp_providers[name] = {
        command = "gemini",
        args = args,
        env = {
          NODE_NO_WARNINGS = "1",
          GEMINI_API_KEY = os.getenv("GEMINI_API_KEY"), -- you must set this env variable
        },
      }
    end
  end,
}
