return {
  "zbirenbaum/copilot.lua",
  event = "BufEnter",
  config = function(_, opts)
    local copilot = require("copilot")
    copilot.setup(opts)

    local command = Snacks.toggle.new({
      id = "copilot",
      name = "Copilot",
      get = function()
        return require("copilot.client").is_disabled() == false
      end,
      set = function(state)
        if state then
          require("copilot.command").enable()
        else
          require("copilot.command").disable()
        end
      end,
    })

    command:map("<leader>uO")

    command:set(true)
  end,
}
