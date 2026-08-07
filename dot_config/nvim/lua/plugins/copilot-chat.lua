return {
  {
    "saghen/blink.cmp",
    optional = true,
    ---@module 'blink.cmp'
    ---@type blink.cmp.Config
    opts = {
      sources = {
        providers = {
          path = {
            enabled = function()
              return vim.bo.filetype ~= "copilot-chat"
            end,
          },
        },
      },
    },
  },
  {
    "CopilotC-Nvim/CopilotChat.nvim",
    branch = "main",
    cmd = "CopilotChat",
    keys = {
      { "<leader>ap", nil },
      {
        "<leader>ap",
        function()
          require("CopilotChat.integrations.snacks").pick(
            require("CopilotChat.actions").prompt_actions(),
            { layout = "vscode" }
          )
        end,
        desc = "Prompt Actions (CopilotChat)",
        mode = { "n", "v" },
      },
    },
    opts = function()
      local user = vim.env.USER or "User"
      user = user:sub(1, 1):upper() .. user:sub(2)
      return {
        auto_insert_mode = true,
        question_header = "  " .. user .. " ",
        answer_header = "  Copilot ",
        window = {
          width = 0.4,
        },
        providers = {
          copilot = {},
          github_models = {},
          copilot_embeddings = {},
          ollama = {
            prepare_input = require("CopilotChat.config.providers").copilot.prepare_input,
            prepare_output = require("CopilotChat.config.providers").copilot.prepare_output,

            get_models = function(headers)
              local response, err = require("CopilotChat.utils").curl_get("http://localhost:1234/v1/models", {
                headers = headers,
                json_response = true,
              })

              if err then
                error(err)
              end

              return vim.tbl_map(function(model)
                return {
                  id = model.id,
                  name = model.id,
                }
              end, response.body.data)
            end,

            embed = function(inputs, headers)
              local response, err = require("CopilotChat.utils").curl_post("http://localhost:1234/v1/embeddings", {
                headers = headers,
                json_request = true,
                json_response = true,
                body = {
                  input = inputs,
                  model = "all-minilm",
                },
              })

              if err then
                error(err)
              end

              return response.body.data
            end,

            get_url = function()
              return "http://localhost:1234/v1/chat/completions"
            end,
          },
        },
      }
    end
  },
}
