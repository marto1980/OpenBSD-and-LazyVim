return {
  "yetone/avante.nvim",
  build = "gmake BUILD_FROM_SOURCE=true",
  opts = {
    provider = "gemini-cli",
    acp_providers = {
      ["gemini-cli"] = {
        command = "gemini",
        args = { "--experimental-acp", "-m", "gemini-2.5-flash" },
        env = {
          -- This ensures the ACP uses the higher-limit model
          GEMINI_MODEL = "gemini-2.5-flash",
        },
      },
    },
  },
}
