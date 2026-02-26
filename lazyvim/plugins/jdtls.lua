return {
  {
    "mfussenegger/nvim-jdtls",
    opts = function(_, opts)
      local jdtls_base = "/home/marto/build/jdt-language-server"
      local launcher_jar = vim.fn.glob(jdtls_base .. "/plugins/org.eclipse.equinox.launcher_*.jar")
      local config_dir = jdtls_base .. "/config_linux"
      local workspace_dir = os.getenv("HOME") .. "/.cache/jdtls/workspace"

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
      }

      -- This function is what LazyVim calls; we define it to return our cmd
      opts.full_cmd = function()
        return opts.jdtls.cmd
      end

      return opts
    end,
  },
}
