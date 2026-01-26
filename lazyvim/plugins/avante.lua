return {
  "yetone/avante.nvim",

  -- Build function for OpenBSD
  build = function()
    local uname = vim.uv.os_uname().sysname
    local plugin_dir = vim.fn.stdpath("data") .. "/lazy/avante.nvim"
    local makefile = plugin_dir .. "/Makefile"
    local local_makefile = plugin_dir .. "/Makefile.local"

    -- Non-OpenBSD: default build
    if uname ~= "OpenBSD" then
      vim.fn.system("gmake BUILD_FROM_SOURCE=true")
      return
    end

    -- Portable file copy function
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

    -- Copy Makefile to local if it doesn't exist
    if not vim.loop.fs_stat(local_makefile) then
      local ok = copy_file(makefile, local_makefile)
      if not ok then
        error("Failed to copy Makefile -> Makefile.local")
      end
    end

    -- Patch local Makefile for OpenBSD
    local lines = vim.fn.readfile(local_makefile)
    local patched = {}
    local already = false

    for _, l in ipairs(lines) do
      table.insert(patched, l)
      if l:match("^else ifeq %(%$%(UNAME%), Darwin%)") then
        if not already then
          table.insert(patched, "else ifeq ($(UNAME), OpenBSD)")
          table.insert(patched, "\tOS := linux")
          table.insert(patched, "\tEXT := so")
          already = true
        end
      end
    end

    vim.fn.writefile(patched, local_makefile)

    -- Build using patched Makefile.local
    vim.fn.system({
      "sh",
      "-c",
      "cd " .. plugin_dir .. " && gmake -f Makefile.local BUILD_FROM_SOURCE=true",
    })
  end,

  -- Avante configuration
  config = function(_, opts)
    -- Patch OS detection in Lua runtime
    local ok, utils = pcall(require, "avante.utils")
    if ok and utils.get_os_name then
      local orig = utils.get_os_name
      utils.get_os_name = function()
        local os_name = vim.uv.os_uname().sysname
        if os_name == "OpenBSD" then
          return "linux" -- treat OpenBSD as Linux
        end
        return orig()
      end
    end

    require("avante").setup(opts)
  end,

  -- Options
  opts = {
    provider = "openrouter", -- using OpenRouter ACP
    acp_providers = {
      ["openrouter"] = {
        command = "openrouter",
        args = { "--model", "default" },
        env = {}, -- add PATH or other env vars if needed
      },
    },
  },
}
