local GameUtils = require("vim-be-good.game-utils")
local log = require("vim-be-good.log")

local gameLineCount = 10

local instructions = {
  "Make the call on line 7 match the desired call on line 5.",
  "Move one argument chunk at a time (including commas/spaces).",
}

local orders = {
  { 2, 1, 4, 3 },
  { 3, 1, 2, 4 },
  { 4, 2, 1, 3 },
  { 2, 4, 3, 1 },
  { 3, 4, 1, 2 },
}
local languages = {
  { name = "typescript", filetype = "typescript", comment = "//" },
  { name = "python", filetype = "python", comment = "#" },
  { name = "rust", filetype = "rust", comment = "//" },
}

local function pickLanguage(lastLanguageName)
  if #languages == 1 then
    return languages[1]
  end

  local picked = languages[math.random(1, #languages)]
  local attempts = 0
  while picked.name == lastLanguageName and attempts < 8 do
    picked = languages[math.random(1, #languages)]
    attempts = attempts + 1
  end

  return picked
end

local ArgReorder = {}
function ArgReorder:new(difficulty, window)
  log.info("NewArgReorder", difficulty, window)
  local round = {
    window = window,
    difficulty = difficulty,
    lastLanguageName = nil,
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
  local language = pickLanguage(self.lastLanguageName)
  self.lastLanguageName = language.name

  local desiredCall = ""
  local currentCall = ""
  if language.name == "typescript" then
    desiredCall = "const out = " .. fnName .. "(" .. table.concat(targetArgs, ", ") .. ");"
    currentCall = "const out = " .. fnName .. "(" .. table.concat(sourceArgs, ", ") .. ");"
  elseif language.name == "python" then
    desiredCall = "out = " .. fnName .. "(" .. table.concat(targetArgs, ", ") .. ")"
    currentCall = "out = " .. fnName .. "(" .. table.concat(sourceArgs, ", ") .. ")"
  else
    desiredCall = "let out = " .. fnName .. "(" .. table.concat(targetArgs, ", ") .. ");"
    currentCall = "let out = " .. fnName .. "(" .. table.concat(sourceArgs, ", ") .. ");"
  end

  local lines = GameUtils.createEmpty(gameLineCount)
  lines[3] = language.comment .. " language: " .. language.name
  lines[5] = language.comment .. " target args: " .. table.concat(targetArgs, ", ")
  lines[7] = currentCall

  local answer = GameUtils.createEmpty(gameLineCount)
  answer[3] = lines[3]
  answer[5] = lines[5]
  answer[7] = desiredCall

  local expected = table.concat(GameUtils.filterEmptyLines(answer), ""):lower():gsub("%s+", "")
  local hint = "Put cursor on arg start. Use df, (or dF, for last arg) to cut. Jump to target comma with f, then paste P/p."

  self.config = {
    roundTime = math.floor(GameUtils.difficultyToTime[self.difficulty] * 1.8),
    question_lines = lines,
    answer_lines = answer,
    expected = expected,
    hint = hint,
    language = language,
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
  if self.window and self.window.bufh and self.config and self.config.language then
    vim.bo[self.window.bufh].filetype = self.config.language.filetype
  end

  local cursorIdx = 7
  return self.config.question_lines, cursorIdx
end

function ArgReorder:name()
  return "argreorder"
end

return ArgReorder
