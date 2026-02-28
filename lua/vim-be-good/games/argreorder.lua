local GameUtils = require("vim-be-good.game-utils")
local log = require("vim-be-good.log")

local gameLineCount = 10

local instructions = {
  "Reorder function call arguments to match the target order.",
}

local orders = {
  { 2, 1, 4, 3 },
  { 3, 1, 2, 4 },
  { 4, 2, 1, 3 },
  { 2, 4, 3, 1 },
  { 3, 4, 1, 2 },
}

local ArgReorder = {}
function ArgReorder:new(difficulty, window)
  log.info("NewArgReorder", difficulty, window)
  local round = {
    window = window,
    difficulty = difficulty,
  }

  self.__index = self
  return setmetatable(round, self)
end

function ArgReorder:getInstructions()
  return instructions
end

local function applyOrder(args, order)
  local out = {}
  for idx = 1, #order do
    out[idx] = args[order[idx]]
  end
  return out
end

function ArgReorder:getConfig()
  log.info("getConfig", self.difficulty, GameUtils.difficultyToTime[self.difficulty])

  local a = GameUtils.getRandomWord()
  local b = GameUtils.getRandomWord()
  local c = GameUtils.getRandomWord()
  local d = GameUtils.getRandomWord()
  local fnName = "mix_" .. GameUtils.getRandomWord()

  local sourceArgs = { a, b, c, d }
  local order = orders[math.random(1, #orders)]
  local targetArgs = applyOrder(sourceArgs, order)

  local lines = GameUtils.createEmpty(gameLineCount)
  lines[5] = "target order: " .. table.concat(order, ",")
  lines[7] = fnName .. "(" .. table.concat(sourceArgs, ", ") .. ")"

  local answer = GameUtils.createEmpty(gameLineCount)
  answer[5] = lines[5]
  answer[7] = fnName .. "(" .. table.concat(targetArgs, ", ") .. ")"

  local expected = table.concat(GameUtils.filterEmptyLines(answer), ""):lower():gsub("%s+", "")
  local hint = "Try text objects + motions (f, dt, p) or a macro for fast argument swaps."

  self.config = {
    roundTime = math.floor(GameUtils.difficultyToTime[self.difficulty] * 1.8),
    question_lines = lines,
    answer_lines = answer,
    expected = expected,
    hint = hint,
  }

  return self.config
end

function ArgReorder:checkForWin()
  local lines = self.window.buffer:getGameLines()
  local trimmed_lines = GameUtils.trimLines(lines)
  local concatenated = table.concat(GameUtils.filterEmptyLines(trimmed_lines), "")
  local lowercased = concatenated:lower()
  local trimmed = lowercased:gsub("%s+", "")
  local winner = trimmed == self.config.expected

  if winner then
    vim.cmd("stopinsert")
  end

  return winner
end

function ArgReorder:render()
  local cursorIdx = 7
  return self.config.question_lines, cursorIdx
end

function ArgReorder:name()
  return "argreorder"
end

return ArgReorder
