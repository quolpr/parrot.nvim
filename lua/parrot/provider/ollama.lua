local logger = require("parrot.logger")
local Job = require("plenary.job")

local Ollama = {}
Ollama.__index = Ollama

function Ollama:new(endpoint, api_key)
  local o = {
    endpoint = endpoint,
    api_key = api_key,
    name = "ollama",
    ollama_installed = vim.fn.executable("ollama"),
  }
  setmetatable(o, self)
  self.__index = self
  return o
end

function Ollama:curl_params()
  return { self.endpoint }
end

function Ollama:verify()
  return true
end

function Ollama:preprocess_messages(messages)
  return messages
end

function Ollama:add_system_prompt(messages, sys_prompt)
  if sys_prompt ~= "" then
    table.insert(messages, { role = "system", content = sys_prompt })
  end
  return messages
end

function Ollama:process(line)
  if line:match("message") and line:match("content") then
    line = vim.json.decode(line)
    if line.message and line.message.content then
      return line.message.content
    end
  end
end

function Ollama:check(agent)
  if not self.ollama_installed then
    logger.warning("ollama not found.")
    return
  end
  local model = ""
  if type(agent.model) == "string" then
    model = agent.model
  else
    model = agent.model.model
  end

  local handle = io.popen("ollama list")
  local result = handle:read("*a")
  handle:close()

  local lines = {}
  for line in result:gmatch("[^\r\n]+") do
    table.insert(lines, line)
  end
  local found_match = false
  for _, line in ipairs(lines) do
    if string.match(line, model) ~= nil then
      found_match = true
    end
  end
  if not found_match then
    if not pcall(require, "plenary") then
      print("Plenary not installed. Please install nvim-lua/plenary.nvim to use this feature.")
      return
    end
    local confirm = vim.fn.confirm("ollama model " .. model .. " not found. Download now?", "&Yes\n&No", 1)
    if confirm == 1 then
      local job = Job:new({
        command = "ollama",
        args = { "pull", model },
        on_exit = function(j, return_val)
          logger.info("Download finished with exit code: " .. return_val)
        end,
        on_stderr = function(j, data)
          print("Downloading, please wait: " .. data)
          if j ~= nil then
            logger.error(vim.inspect(j:result()))
          end
        end,
      })
      job:start()
      return true
    else
      return false
    end
  end
end

return Ollama