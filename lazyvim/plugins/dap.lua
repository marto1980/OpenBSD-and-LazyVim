return {
  "mfussenegger/nvim-dap",
  opts = function(_, opts)
    local dap = require("dap")

    if dap.listeners.before.event_exited then
      dap.listeners.before.event_exited["dapui_config"] = nil
    end

    if dap.listeners.before.event_terminated then
      dap.listeners.before.event_terminated["dapui_config"] = nil
    end

    -- Cleanup targeting ONLY the java process on port 8080
    local function kill_java_backend()
      -- This filters fstat to find lines containing 'java' and '8080', then pulls the PID safely
      local cmd = "kill -9 $(fstat | grep java | grep 8080 | awk '{print $3}' | uniq) 2>/dev/null"
      os.execute(cmd)
    end

    -- Hook into both nvim-dap events to ensure it catches the termination
    dap.listeners.before.disconnect["kill-on-8080"] = kill_java_backend
    dap.listeners.before.terminate["kill-on-8080"] = kill_java_backend

    return opts
  end,
}
