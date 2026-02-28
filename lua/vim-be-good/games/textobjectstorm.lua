local GameUtils = require("vim-be-good.game-utils")
local log = require("vim-be-good.log")

local gameLineCount = 10
local difficultyTimeMultiplier = {
    noob = 2.0,
    easy = 1.6,
    medium = 1.2,
    hard = 1.0,
    nightmare = 0.85,
    tpope = 0.7,
}

local currentInstructions = {
    "Change inside containers to bar.",
}

local function shuffle(items)
    for i = #items, 2, -1 do
        local j = math.random(1, i)
        items[i], items[j] = items[j], items[i]
    end
end

local TextObjectStorm = {}
function TextObjectStorm:new(difficulty, window)
    log.info("NewTextObjectStorm", difficulty, window)
    local round = {
        window = window,
        difficulty = difficulty,
    }

    self.__index = self
    return setmetatable(round, self)
end

function TextObjectStorm:getInstructions()
    return currentInstructions
end

function TextObjectStorm:getConfig()
    log.info("getConfig", self.difficulty, GameUtils.difficultyToTime[self.difficulty])

    local one = GameUtils.getRandomWord()
    local two = GameUtils.getRandomWord()
    local three = GameUtils.getRandomWord()
    local four = GameUtils.getRandomWord()

    local variants = {
        {
            label = "ci\\\"",
            question = "say(\"" .. one .. "\")",
            answer = "say(\"bar\")",
        },
        {
            label = "ci(",
            question = "calc(" .. two .. ")",
            answer = "calc(bar)",
        },
        {
            label = "ci[",
            question = "list([" .. three .. "])",
            answer = "list([bar])",
        },
        {
            label = "ci{",
            question = "obj({" .. four .. "})",
            answer = "obj({bar})",
        },
    }
    shuffle(variants)

    local lines = GameUtils.createEmpty(gameLineCount)
    local answer = GameUtils.createEmpty(gameLineCount)
    local startLine = 6
    for idx = 1, #variants do
        local lineNo = startLine + idx - 1
        lines[lineNo] = variants[idx].question
        answer[lineNo] = variants[idx].answer
    end

    local expected = table.concat(GameUtils.filterEmptyLines(answer), ""):lower():gsub("%s+", "")
    currentInstructions = {
        "Change inside containers to bar.",
    }

    local hint = "Text-object sequence this round: " ..
        variants[1].label .. " " .. variants[2].label .. " " .. variants[3].label .. " " .. variants[4].label ..
        "; use . to repeat when possible."

    local baseRoundTime = GameUtils.difficultyToTime[self.difficulty]
    local multiplier = difficultyTimeMultiplier[self.difficulty] or 1.0

    self.config = {
        roundTime = math.floor(baseRoundTime * multiplier),
        question_lines = lines,
        answer_lines = answer,
        expected = expected,
        hint = hint,
    }

    return self.config
end

function TextObjectStorm:checkForWin()
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

function TextObjectStorm:render()
    local cursorIdx = 6
    return self.config.question_lines, cursorIdx
end

function TextObjectStorm:name()
    return "textobjectstorm"
end

return TextObjectStorm
