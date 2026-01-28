-- Constants
local OPENBSD = "OpenBSD"
local LINUX_OS = "linux"
local SO_EXTENSION = "so"
local MAKEFILE_LOCAL = "Makefile.local"
local MODE_LEGACY = "legacy"
local MODE_AGENTIC = "agentic"
local OPENROUTER_ENDPOINT = "https://openrouter.ai/api/v1"
local DEFAULT_TIMEOUT_MS = 60000 -- 60 seconds for longer generation tasks
local DEFAULT_TEMPERATURE = 0.75 -- Balanced between creativity and consistency

-- Helper Functions

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
    -- When we reach the generic else, insert OpenBSD *before* it
    if l:match("^else$") and not inserted then
      table.insert(patched, "else ifeq ($(UNAME), OpenBSD)")
      table.insert(patched, "\tOS := " .. LINUX_OS)
      table.insert(patched, "\tEXT := " .. SO_EXTENSION)
      inserted = true
    end
    table.insert(patched, l)
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
--- @param name string Provider name
--- @param model string Model identifier
--- @param extra table|nil Extra request body parameters
--- @param global_extra table Global default parameters
--- @return table provider Provider configuration

local function create_openrouter_provider(name, model, extra, global_extra)
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
--- @param name string Provider name
--- @param model string Model identifier (empty string for auto)
--- @return table provider ACP provider configuration
local function create_acp_provider(name, model)
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
local function switch_provider()
  local avante_config = require("avante.config")
  local snacks = require("snacks")

  -- Define all available providers with descriptions
  local providers = {
    { name = "claude-4.5-sonnet", desc = "Claude 4.5 Sonnet (Legacy)", mode = MODE_LEGACY },
    { name = "claude-4.5-opus", desc = "Claude 4.5 Opus (Legacy)", mode = MODE_LEGACY },
    { name = "gemini-cli", desc = "Gemini Auto (Agentic)", mode = MODE_AGENTIC },
    { name = "gemini-pro", desc = "Gemini 3 Pro Preview (Agentic)", mode = MODE_AGENTIC },
    { name = "gemini-flash", desc = "Gemini 3 Flash Preview (Agentic)", mode = MODE_AGENTIC },
    { name = "grok-code-fast", desc = "Grok Code Fast (Legacy)", mode = MODE_LEGACY },
    { name = "gpt-4.1", desc = "GPT-4.1 (Legacy)", mode = MODE_LEGACY },
    { name = "gemini-3-flash", desc = "Gemini 3 Flash (Legacy)", mode = MODE_LEGACY },
    { name = "claude-4.5-haiku", desc = "Claude 4.5 Haiku (Legacy)", mode = MODE_LEGACY },
    { name = "gpt-4o-mini", desc = "GPT-4o Mini (Legacy)", mode = MODE_LEGACY },
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
      opts.providers[name] = create_openrouter_provider(name, model, extra, global_extra)
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

    -- ✅ Configure add ACP providers
    local acp_models = {
      { "gemini-cli", "" },
      { "gemini-pro", "gemini-3-pro-preview" },
      { "gemini-flash", "gemini-3-flash-preview" },
    }
    opts.acp_providers = opts.acp_providers or {}
    for _, entry in ipairs(acp_models) do
      local name, model = entry[1], entry[2]
      opts.acp_providers[name] = create_acp_provider(name, model)
    end
  end,
}
