return {
  {
    "mfussenegger/nvim-jdtls",
    ft = "java",
    opts = function(_, opts)
      -- Base paths
      local home = os.getenv("HOME")
      local jdtls_base = home .. "/build/jdt-language-server"
      local launcher_jar = vim.fn.glob(jdtls_base .. "/plugins/org.eclipse.equinox.launcher_*.jar")
      local config_dir = jdtls_base .. "/config_linux"
      -- Root detection
      local root_dir = vim.fs.root(0, { "gradlew", ".git", "mvnw", "pom.xml", "build.gradle" })
      if not root_dir then
        return
      end
      -- Project-specific workspace
      local project_name = vim.fn.fnamemodify(root_dir, ":p:h:t")
      local workspace_dir = home .. "/.cache/jdtls/workspace/" .. project_name

      -- We manually define the full cmd here to satisfy LazyVim's expectations
      opts.jdtls = {
        cmd = {
          "/usr/local/jdk-25/bin/java",
          "-Declipse.application=org.eclipse.jdt.ls.core.id1",
          "-Dosgi.bundles.defaultStartLevel=4",
          "-Declipse.product=org.eclipse.jdt.ls.core.product",
          "-Dlog.protocol=true",
          "-Dlog.level=ALL",
          "-Xmx1g",
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
        },
        root_dir = root_dir,
        settings = {
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
        },
        -- for debug support at a later stage
        init_options = {
          bundles = {},
        },
      }

      -- This function is what LazyVim calls; we define it to return our cmd
      opts.full_cmd = function()
        return opts.jdtls.cmd
      end

      return opts
    end,
  },
}
