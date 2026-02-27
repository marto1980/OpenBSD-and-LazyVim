--[[
Avante.nvim Configuration

This configuration includes special handling for OpenBSD:
- OpenBSD is not recognized by the default Makefile
- We patch the Makefile to treat OpenBSD as Linux
- We monkey-patch avante.utils.get_os_name to return "linux" on OpenBSD

Architecture:
- Legacy mode: Traditional completion with manual approval
- Agentic mode: Autonomous AI agent using ACP (Agentic Code Provider)

Adding new providers:
1. Add to PROVIDER_CONFIGS below with all metadata
2. The provider will automatically appear in the picker (<leader>am)
3. For ACP providers, set is_acp = true
--]]

-- Build-related constants
local OPENBSD = "OpenBSD"
local LINUX_OS = "linux"
local SO_EXTENSION = "so"
local MAKEFILE_LOCAL = "Makefile.local"

-- Provider mode constants
local MODE_LEGACY = "legacy"
local MODE_AGENTIC = "agentic"

-- API constants
local OPENROUTER_ENDPOINT = "https://openrouter.ai/api/v1"

-- Configuration constants
local DEFAULT_TIMEOUT_MS = 60000 -- 60 seconds for longer generation tasks
-- Temperature controls randomness: 0=deterministic, 1=creative, 0.75=balanced
local DEFAULT_TEMPERATURE = 0.75 -- Balanced between creativity and consistency
local MAX_TOKENS_LONG_CONTEXT = 32768

-- Provider configurations with complete metadata
-- This is the single source of truth for all providers
local PROVIDER_CONFIGS = {
  -- Core generalist / explanation / documentation
  {
    name = "claude-4.5-sonnet",
    model = "anthropic/claude-sonnet-4.5",
    desc = "Claude 4.5 Sonnet",
    mode = MODE_LEGACY,
    comment = "code refactor / deep reasoning / expensive",
  },
  {
    name = "claude-4.5-opus",
    model = "anthropic/claude-opus-4.5",
    desc = "Claude 4.5 Opus",
    mode = MODE_LEGACY,
    comment = "documentation & architectural writing / expensive",
  },
  -- ACP (Agentic Code Provider) models
  {
    name = "gemini-cli",
    model = "",
    desc = "Gemini Auto",
    mode = MODE_AGENTIC,
    is_acp = true,
    comment = "auto-select best model",
  },
  {
    name = "gemini-pro",
    model = "gemini-3.1-pro-preview",
    desc = "Gemini 3.1 Pro Preview",
    mode = MODE_AGENTIC,
    is_acp = true,
    comment = "autonomous complex refactoring / agentic deep reasoning / expensive",
  },
  {
    name = "gemini-flash",
    model = "gemini-3-flash-preview",
    desc = "Gemini 3 Flash Preview",
    mode = MODE_AGENTIC,
    is_acp = true,
    comment = "autonomous quick fixes / fast agentic refactoring / low cost",
  },
  -- Strong programming support
  {
    name = "grok-code-fast",
    model = "x-ai/grok-code-fast-1",
    desc = "Grok Code Fast",
    mode = MODE_LEGACY,
    comment = "code completion / autocomplete / very cheap",
  },
  -- Strong generalist baseline
  {
    name = "gpt-4.1",
    model = "openai/gpt-4.1",
    desc = "GPT-4.1",
    mode = MODE_LEGACY,
    comment = "code refactor / deep reasoning / medium cost",
  },
  -- Long-context / tool usage
  {
    name = "gemini-3-flash",
    model = "google/gemini-3-flash-preview",
    desc = "Gemini 3 Flash",
    mode = MODE_LEGACY,
    extra = { max_tokens = MAX_TOKENS_LONG_CONTEXT },
    comment = "long context editing / large files / low cost",
  },
  -- Lightweight complement
  {
    name = "claude-4.5-haiku",
    model = "anthropic/claude-haiku-4.5",
    desc = "Claude 4.5 Haiku",
    mode = MODE_LEGACY,
    comment = "quick hints / drafts / low cost",
  },
  {
    name = "gpt-4o-mini",
    model = "openai/gpt-4o-mini",
    desc = "GPT-4o Mini",
    mode = MODE_LEGACY,
    comment = "quick hints / drafts / very cheap",
  },
  -- Free models
  {
    name = "trinity-large-preview",
    model = "arcee-ai/trinity-large-preview:free",
    desc = "Trinity Large Preview (free)",
    mode = MODE_LEGACY,
    comment = "creative writing / deep reasoning / very long contexts / free",
  },
  {
    name = "trinity-mini",
    model = "arcee-ai/trinity-mini:free",
    desc = "Trinity Mini (free)",
    mode = MODE_LEGACY,
    comment = "deep reasoning / long contexts /robust function calling / multi-step agent workflows / free",
  },
}

-- Helper Functions

--- Validate that required API keys are set
--- @return boolean success Whether all required keys are present
local function validate_api_keys()
  local keys_to_check = {
    { name = "OPENROUTER_API_KEY", required = true },
    { name = "GEMINI_API_KEY", required = false }, -- Only needed for ACP
  }

  local all_valid = true
  for _, key in ipairs(keys_to_check) do
    if not os.getenv(key.name) then
      local level = key.required and vim.log.levels.WARN or vim.log.levels.INFO
      vim.notify(string.format("Avante: %s not set", key.name), level, { title = "Avante Configuration" })
      if key.required then
        all_valid = false
      end
    end
  end
  return all_valid
end

--- Create a disabled provider configuration
--- @return table provider Disabled provider configuration
local function disable_provider()
  return {
    __inherited_from = "openai",
    enabled = false,
  }
end

--- Copy a file from source to destination
--- @param src string Source file path
--- @param dst string Destination file path
--- @return boolean success Whether the copy succeeded
--- @return string|nil error Error message if failed
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

--- Patch Makefile to recognize OpenBSD as a valid platform
--- @param makefile_path string Path to the Makefile to patch
--- @return boolean success Whether the patch succeeded
local function patch_makefile_for_openbsd(makefile_path)
  local lines = vim.fn.readfile(makefile_path)
  local patched = {}
  local inserted = false

  for _, l in ipairs(lines) do
    if l:match("^else$") and not inserted then
      table.insert(patched, "else ifeq ($(UNAME), OpenBSD)")
      table.insert(patched, "\tOS := " .. LINUX_OS)
      table.insert(patched, "\tEXT := " .. SO_EXTENSION)
      inserted = true
    end
    table.insert(patched, l)
  end

  if not inserted then
    vim.notify("Warning: Could not find insertion point in Makefile", vim.log.levels.WARN)
    return false
  end

  vim.fn.writefile(patched, makefile_path)
  return true
end

--- Build avante.nvim for OpenBSD by patching and compiling
--- @param plugin_dir string Plugin directory path
--- @return boolean success Whether the build succeeded
local function build_for_openbsd(plugin_dir)
  local makefile = plugin_dir .. "/Makefile"
  local local_makefile = plugin_dir .. "/" .. MAKEFILE_LOCAL

  -- Copy and patch Makefile if not already done
  if not vim.uv.fs_stat(local_makefile) then
    local success, err = copy_file(makefile, local_makefile)
    if not success then
      vim.notify("Avante: " .. err, vim.log.levels.ERROR)
      return false
    end

    if not patch_makefile_for_openbsd(local_makefile) then
      vim.notify("Avante: Failed to patch Makefile", vim.log.levels.ERROR)
      return false
    end
  end

  -- Build using the patched Makefile
  local result = vim.fn.system({
    "sh",
    "-c",
    "cd " .. plugin_dir .. " && gmake -f " .. MAKEFILE_LOCAL .. " BUILD_FROM_SOURCE=true",
  })

  if vim.v.shell_error ~= 0 then
    vim.notify("Avante OpenBSD build failed: " .. result, vim.log.levels.ERROR)
    return false
  end

  return true
end

--- Create an OpenRouter provider configuration
--- @param model string Model identifier
--- @param extra table|nil Extra request body parameters
--- @param global_extra table Global default parameters
--- @return table provider Provider configuration
local function create_openrouter_provider(model, extra, global_extra)
  local provider = {
    __inherited_from = "openai",
    endpoint = OPENROUTER_ENDPOINT,
    api_key_name = "OPENROUTER_API_KEY",
    model = model,
  }

  -- Merge per-model overrides with global defaults
  provider.extra_request_body = vim.tbl_extend("force", vim.deepcopy(global_extra), extra or {})
  return provider
end

--- Create an ACP (Agentic Code Provider) configuration
--- @param model string Model identifier (empty string for auto)
--- @return table provider ACP provider configuration
local function create_acp_provider(model)
  local args = { "--experimental-acp" }
  if model ~= "" then
    table.insert(args, "--model")
    table.insert(args, model)
  end

  return {
    command = "gemini",
    args = args,
    env = {
      NODE_NO_WARNINGS = "1",
      GEMINI_API_KEY = os.getenv("GEMINI_API_KEY"),
    },
  }
end

--- Show provider picker and switch to selected provider
--- Dynamically generates picker items from PROVIDER_CONFIGS
--- Shows preview window with mode and comment information
local function switch_provider()
  local avante_config = require("avante.config")
  local snacks = require("snacks")

  -- Format items for the picker with visual indicator for current provider
  local current_provider = avante_config.provider
  local items = {}

  for _, p in ipairs(PROVIDER_CONFIGS) do
    local indicator = (p.name == current_provider) and "● " or "  "

    -- Build preview content with provider details
    local preview_lines = {}
    table.insert(preview_lines, "# " .. p.name)
    table.insert(preview_lines, "")
    table.insert(preview_lines, "**Description:** " .. p.desc)
    table.insert(preview_lines, "")
    table.insert(preview_lines, "**Mode:** " .. (p.mode == MODE_AGENTIC and "🤖 Agentic" or "✋ Legacy"))
    table.insert(preview_lines, "")

    if p.model and p.model ~= "" then
      table.insert(preview_lines, "**Model:** " .. p.model)
      table.insert(preview_lines, "")
    end

    if p.is_acp then
      table.insert(preview_lines, "**Type:** ACP (Agentic Code Provider)")
      table.insert(preview_lines, "")
    end

    if p.comment then
      table.insert(preview_lines, "**Use Case:**")
      for part in string.gmatch(p.comment, "[^/]+") do
        table.insert(preview_lines, "• " .. vim.trim(part))
      end
      table.insert(preview_lines, "")
    end

    -- Add mode explanation
    table.insert(preview_lines, "---")
    table.insert(preview_lines, "")
    if p.mode == MODE_AGENTIC then
      table.insert(preview_lines, "**Agentic Mode:**")
      table.insert(preview_lines, "• Autonomous AI agent using ACP")
      table.insert(preview_lines, "• Automatically applies changes")
      table.insert(preview_lines, "• Best for rapid iteration")
    else
      table.insert(preview_lines, "**Legacy Mode:**")
      table.insert(preview_lines, "• Traditional completion flow")
      table.insert(preview_lines, "• Manual approval required")
      table.insert(preview_lines, "• More control over changes")
    end

    table.insert(items, {
      text = string.format("%s%-30s %s", indicator, p.name, p.desc),
      provider = p.name,
      mode = p.mode,
      comment = p.comment,
      model = p.model,
      is_acp = p.is_acp or false,
      preview = {
        text = table.concat(preview_lines, "\n"),
        ft = "markdown",
      },
    })
  end

  -- Show picker with preview window
  snacks.picker({
    items = items,
    prompt = "Select Avante Provider",
    format = "text",
    preview = "preview",
    layout = {
      preset = "default", -- Use default layout which includes preview
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
end

return {
  "yetone/avante.nvim",

  -- Build function with special handling for OpenBSD
  -- Non-OpenBSD systems: standard gmake build
  -- OpenBSD systems: patch Makefile to recognize OpenBSD, then build

  build = function()
    ---@diagnostic disable-next-line: undefined-field
    local uname = vim.uv.os_uname().sysname
    local plugin_dir = vim.fn.stdpath("data") .. "/lazy/avante.nvim"

    -- Non-OpenBSD systems: use standard build process
    if uname ~= OPENBSD then
      local result = vim.fn.system("gmake BUILD_FROM_SOURCE=true")
      if vim.v.shell_error ~= 0 then
        vim.notify("Avante build failed: " .. result, vim.log.levels.ERROR)
      end
      return
    end

    -- OpenBSD: Use helper function to build with patched Makefile
    build_for_openbsd(plugin_dir)
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
    -- Validate required API keys are set
    validate_api_keys()

    -- Monkey-patch avante.utils.get_os_name to report OpenBSD as "linux"
    -- This ensures the plugin uses Linux-compatible binaries on OpenBSD
    local ok, utils = pcall(require, "avante.utils")
    if ok and utils.get_os_name then
      local orig = utils.get_os_name
      utils.get_os_name = function()
        ---@diagnostic disable-next-line: undefined-field
        if vim.uv.os_uname().sysname == OPENBSD then
          return LINUX_OS
        end
        return orig()
      end
    end

    require("avante").setup(opts)
  end,

  keys = {
    {
      "<leader>am",
      switch_provider,
      desc = "Avante: Switch Provider (Claude/Gemini-CLI)",
    },
  },

  opts = function(_, opts)
    -- Disable agentic mode: use legacy mode for manual approval
    -- opts.mode = "legacy"
    opts.windows = {
      input = {
        height = 16, -- make prompt window higher
      },
    }
    -- Default starting model
    opts.provider = "trinity-large-preview"

    opts.behaviour = vim.tbl_extend("force", opts.behaviour or {}, { support_paste_from_clipboard = true })
    opts.timeout = DEFAULT_TIMEOUT_MS

    -- Global request body settings applied to all providers
    local global_extra = { temperature = DEFAULT_TEMPERATURE }
    opts.extra_request_body = global_extra

    -- Generate providers dynamically from PROVIDER_CONFIGS
    opts.providers = opts.providers or {}
    opts.acp_providers = opts.acp_providers or {}

    for _, config in ipairs(PROVIDER_CONFIGS) do
      if config.is_acp then
        -- ACP (Agentic Code Provider) configuration
        opts.acp_providers[config.name] = create_acp_provider(config.model)
      else
        -- OpenRouter provider configuration
        opts.providers[config.name] = create_openrouter_provider(config.model, config.extra, global_extra)
      end
    end

    -- Disable unwanted default providers using helper function
    local disabled_providers = { "vertex", "vertex_claude", "gemini", "anthropic" }
    for _, provider_name in ipairs(disabled_providers) do
      opts.providers[provider_name] = disable_provider()
    end
  end,
}
