local GameUtils = require("vim-be-good.game-utils")
local log = require("vim-be-good.log")

local gameLineCount = 14
local difficultyTimeMultiplier = {
  noob = 2.8,
  easy = 2.4,
  medium = 2.0,
  hard = 1.7,
  nightmare = 1.4,
  tpope = 1.2,
}

local currentInstructions = {
  "Batch-edit matching lines with :g and :s.",
}

local editProfiles = {
  { targetPrefix = "task", distractors = { "note", "info", "meta" }, from = "pending", to = "done" },
  { targetPrefix = "job", distractors = { "memo", "log", "draft" }, from = "open", to = "closed" },
  { targetPrefix = "ticket", distractors = { "story", "doc", "idea" }, from = "todo", to = "shipped" },
  { targetPrefix = "item", distractors = { "ref", "meta", "stat" }, from = "queued", to = "sent" },
  { targetPrefix = "build", distractors = { "stage", "plan", "check" }, from = "broken", to = "green" },
  { targetPrefix = "alert", distractors = { "note", "memo", "watch" }, from = "new", to = "acked" },
  { targetPrefix = "order", distractors = { "quote", "cart", "ledger" }, from = "hold", to = "paid" },
  { targetPrefix = "deploy", distractors = { "preview", "sandbox", "branch" }, from = "staged", to = "live" },
  { targetPrefix = "review", distractors = { "comment", "thread", "note" }, from = "waiting", to = "approved" },
  { targetPrefix = "sync", distractors = { "cache", "index", "store" }, from = "stale", to = "fresh" },
}

local assignmentStyles = { " = ", ": ", " => " }
local keySeparators = { "_", "-" }
local keyFormats = { "single", "double" }
local operationKinds = {
  "substitute",
  "inverse_substitute",
  "append",
  "prepend",
  "delete",
  "normal_append",
  "move_bottom",
  "copy_inline",
}
local patternKinds = { "starts_with", "contains", "ends_with" }

local function shuffle(items)
  for i = #items, 2, -1 do
    local j = math.random(1, i)
    items[i], items[j] = items[j], items[i]
  end
end

local function pick(items)
  return items[math.random(1, #items)]
end

local function buildKey(prefix, sep, keyFormat, w1, w2)
  if keyFormat == "double" then
    return prefix .. sep .. w1 .. sep .. w2
  end
  return prefix .. sep .. w1
end

local function buildTargetKey(patternKind, prefix, sep, keyFormat, w1, w2)
  if patternKind == "starts_with" then
    return buildKey(prefix, sep, keyFormat, w1, w2)
  end

  if patternKind == "contains" then
    return w1 .. sep .. prefix .. sep .. w2
  end

  -- ends_with
  return w1 .. sep .. prefix
end

local function buildPattern(patternKind, prefix, sep)
  if patternKind == "starts_with" then
    return "^" .. prefix .. sep
  end

  if patternKind == "contains" then
    return sep .. prefix .. sep
  end

  -- ends_with
  return sep .. prefix .. "$"
end

local function moveBottomWouldChange(rows)
  local seenTarget = false
  for _, row in ipairs(rows) do
    if row.target then
      seenTarget = true
    elseif seenTarget then
      return true
    end
  end
  return false
end

local GlobalOps = {}
function GlobalOps:new(difficulty, window)
  log.info("NewGlobalOps", difficulty, window)
  local round = {
    window = window,
    difficulty = difficulty,
  }

  self.__index = self
  return setmetatable(round, self)
end

function GlobalOps:getInstructions()
  return currentInstructions
end

function GlobalOps:getConfig()
  log.info("getConfig", self.difficulty, GameUtils.difficultyToTime[self.difficulty])

  local profile = pick(editProfiles)
  local statusFrom = profile.from
  local statusTo = profile.to
  local targetPrefix = profile.targetPrefix
  local assign = pick(assignmentStyles)
  local sep = pick(keySeparators)
  local keyFormat = pick(keyFormats)
  local operation = pick(operationKinds)
  local patternKind = pick(patternKinds)
  local appendToken = " +" .. GameUtils.getRandomWord()
  local prependToken = GameUtils.getRandomWord() .. "_ "

  local targetCount = math.random(2, 4)
  local distractorCount = math.random(2, 3)
  if operation == "copy_inline" then
    targetCount = math.random(2, 3)
    distractorCount = math.random(2, 2)
  elseif operation == "move_bottom" then
    targetCount = math.random(2, 3)
    distractorCount = math.random(2, 3)
  end
  local maxRows = gameLineCount - 4
  if targetCount + distractorCount > maxRows then
    distractorCount = maxRows - targetCount
  end

  local rows = {}
  for _ = 1, targetCount do
    local w1 = GameUtils.getRandomWord()
    local w2 = GameUtils.getRandomWord()
    table.insert(rows, {
      key = buildTargetKey(patternKind, targetPrefix, sep, keyFormat, w1, w2),
      value = statusFrom,
      target = true,
    })
  end

  for _ = 1, distractorCount do
    local w1 = GameUtils.getRandomWord()
    local w2 = GameUtils.getRandomWord()
    local dPrefix = pick(profile.distractors)
    table.insert(rows, {
      key = buildKey(dPrefix, sep, keyFormat, w1, w2),
      value = statusFrom,
      target = false,
    })
  end
  shuffle(rows)
  if operation == "move_bottom" then
    local attempts = 0
    while not moveBottomWouldChange(rows) and attempts < 10 do
      shuffle(rows)
      attempts = attempts + 1
    end
  end

  local lines = GameUtils.createEmpty(gameLineCount)
  local answer = GameUtils.createEmpty(gameLineCount)
  local startLine = 3
  local rowLines = {}
  local answerRowLines = {}
  for idx = 1, #rows do
    local row = rows[idx]
    local lineNo = startLine + idx - 1
    local lineText = row.key .. assign .. row.value
    lines[lineNo] = lineText
    table.insert(rowLines, lineText)

    local answerText = lineText
    if operation == "substitute" then
      if row.target then
        answerText = row.key .. assign .. statusTo
      end
      table.insert(answerRowLines, answerText)
    elseif operation == "inverse_substitute" then
      if not row.target then
        answerText = row.key .. assign .. statusTo
      end
      table.insert(answerRowLines, answerText)
    elseif operation == "append" then
      if row.target then
        answerText = lineText .. appendToken
      end
      table.insert(answerRowLines, answerText)
    elseif operation == "prepend" then
      if row.target then
        answerText = prependToken .. lineText
      end
      table.insert(answerRowLines, answerText)
    elseif operation == "delete" then
      if not row.target then
        table.insert(answerRowLines, answerText)
      end
    elseif operation == "normal_append" then
      if row.target then
        answerText = lineText .. ";"
      end
      table.insert(answerRowLines, answerText)
    end
  end

  if operation == "move_bottom" then
    for _, row in ipairs(rows) do
      if not row.target then
        table.insert(answerRowLines, row.key .. assign .. row.value)
      end
    end
    for _, row in ipairs(rows) do
      if row.target then
        table.insert(answerRowLines, row.key .. assign .. row.value)
      end
    end
  elseif operation == "copy_inline" then
    for _, row in ipairs(rows) do
      local lineText = row.key .. assign .. row.value
      table.insert(answerRowLines, lineText)
      if row.target then
        table.insert(answerRowLines, lineText)
      end
    end
  end

  for idx = 1, #answerRowLines do
    local lineNo = startLine + idx - 1
    if lineNo <= gameLineCount then
      answer[lineNo] = answerRowLines[idx]
    else
      break
    end
  end

  local expected = table.concat(GameUtils.filterEmptyLines(answer), ""):lower():gsub("%s+", "")

  local targetPattern = buildPattern(patternKind, targetPrefix, sep)
  local operationText = ""
  local hintCmd = ""
  if operation == "substitute" then
    operationText = statusFrom .. " -> " .. statusTo
    hintCmd = ":g/" .. targetPattern .. "/s/" .. statusFrom .. "/" .. statusTo .. "/"
  elseif operation == "inverse_substitute" then
    operationText = "non-matching lines: " .. statusFrom .. " -> " .. statusTo
    hintCmd = ":v/" .. targetPattern .. "/s/" .. statusFrom .. "/" .. statusTo .. "/"
  elseif operation == "append" then
    operationText = "append '" .. appendToken:gsub("^%s+", "") .. "'"
    hintCmd = ":g/" .. targetPattern .. "/s/$/" .. appendToken .. "/"
  elseif operation == "prepend" then
    operationText = "prepend '" .. prependToken:gsub("%s+$", "") .. "'"
    hintCmd = ":g/" .. targetPattern .. "/s/^/" .. prependToken .. "/"
  elseif operation == "delete" then
    operationText = "delete matching lines"
    hintCmd = ":g/" .. targetPattern .. "/d"
  elseif operation == "normal_append" then
    operationText = "normal-mode append ';'"
    hintCmd = ":g/" .. targetPattern .. "/normal A;"
  elseif operation == "move_bottom" then
    operationText = "move matches to bottom"
    hintCmd = ":g/" .. targetPattern .. "/m$"
  elseif operation == "copy_inline" then
    operationText = "copy matches below themselves"
    hintCmd = ":g/" .. targetPattern .. "/t."
  end
  local hintText = "Batch hint: " .. hintCmd

  local patternLabel = "contains '" .. targetPattern .. "'"
  if patternKind == "starts_with" then
    patternLabel = "start with '" .. targetPrefix .. sep .. "'"
  elseif patternKind == "ends_with" then
    patternLabel = "end with '" .. sep .. targetPrefix .. "'"
  end

  currentInstructions = {
    "Batch-edit only lines that " .. patternLabel .. ": " .. operationText .. ".",
  }

  local baseRoundTime = GameUtils.difficultyToTime[self.difficulty]
  local multiplier = difficultyTimeMultiplier[self.difficulty] or 1.0

  self.config = {
    roundTime = math.floor(baseRoundTime * multiplier),
    question_lines = lines,
    answer_lines = answer,
    expected = expected,
    hint = hintText,
  }

  return self.config
end

function GlobalOps:checkForWin()
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

function GlobalOps:render()
  local cursorIdx = 5
  return self.config.question_lines, cursorIdx
end

function GlobalOps:name()
  return "globalops"
end

return GlobalOps
