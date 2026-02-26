return {
  {
    "mfussenegger/nvim-jdtls",
    opts = function(_, opts)
      local home = os.getenv("HOME")
      local jdtls_base = home .. "/build/jdt-language-server"
      local launcher_jar = vim.fn.glob(jdtls_base .. "/plugins/org.eclipse.equinox.launcher_*.jar")

      if launcher_jar == "" then
        vim.notify("JDTLS launcher jar not found", vim.log.levels.ERROR)
        return opts
      end

      local config_dir = jdtls_base .. "/config_linux"

      -- Override how the full command is built
      opts.full_cmd = function(existing_opts)
        local fname = vim.api.nvim_buf_get_name(0)
        local root_dir = existing_opts.root_dir(fname)
        if not root_dir then
          return existing_opts.cmd
        end

        local project_name = existing_opts.project_name(root_dir)
        local workspace_dir = home .. "/.cache/jdtls/workspace/" .. project_name

        return {
          "/usr/local/jdk-25/bin/java",
          "-Declipse.application=org.eclipse.jdt.ls.core.id1",
          "-Dosgi.bundles.defaultStartLevel=4",
          "-Declipse.product=org.eclipse.jdt.ls.core.product",
          "-Dlog.level=ALL",
          "-Xmx1G",
          "--add-modules=ALL-SYSTEM",
          "--add-opens",
          "java.base/java.util=ALL-UNNAMED",
          "--add-opens",
          "java.base/java.lang=ALL-UNNAMED",
          "-jar",
          launcher_jar,
          "-configuration",
          config_dir,
          "-data",
          workspace_dir,
        }
      end

      -- Extend (not replace) existing settings
      opts.settings = vim.tbl_deep_extend("force", opts.settings or {}, {
        java = {
          configuration = {
            runtimes = {
              {
                name = "JavaSE-17",
                path = "/usr/local/jdk-17",
              },
              {
                name = "JavaSE-21",
                path = "/usr/local/jdk-21",
              },
              {
                name = "JavaSE-25",
                path = "/usr/local/jdk-25",
              },
            },
          },
        },
      })

      return opts
    end,
  },
}
