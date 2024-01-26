local GameUtils = require("vim-be-good.game-utils")
local log = require("vim-be-good.log")
local gameLineCount = 8

local instructions = {
    "Replace the words with the given word.",
}


local ReplacyLines = {}
function ReplacyLines:new(difficulty, window)
    log.info("NewWords", difficulty, window)
    local round = {
        window = window,
        difficulty = difficulty,
    }

    self.__index = self
    return setmetatable(round, self)
end

function ReplacyLines:getInstructions()
    return instructions
end

function ReplacyLines:getConfig()
    log.info("getConfig", self.difficulty, GameUtils.difficultyToTime[self.difficulty])
    local lines = GameUtils.createEmpty(gameLineCount)
    local one = GameUtils.getRandomWord()
    local two = "replace_me"
    -- question looks like:
    -- oar
    -- replace_me
    -- replace_me
    lines[6] = one
    lines[7] = two
    lines[8] = two
    -- answer looks like:
    -- oar
    -- oar
    -- oar
    local answer_lines = GameUtils.createEmpty(gameLineCount)
    answer_lines[6] = one
    answer_lines[7] = one
    answer_lines[8] = one

    local concatenated_answer = table.concat(GameUtils.filterEmptyLines(answer_lines), "")
    self.config = {
        roundTime = GameUtils.difficultyToTime[self.difficulty],
        question_lines = lines,
        expected = concatenated_answer,
    }

    return self.config
end

function ReplacyLines:checkForWin()
    local lines = self.window.buffer:getGameLines()
    local trimmed_lines = GameUtils.trimLines(lines)
    local concatenated = table.concat(GameUtils.filterEmptyLines(trimmed_lines), "")
    local lowercased = concatenated:lower()
    local trimmed = lowercased:gsub("%s+", "")
    print('trimmed', trimmed, 'expected', self.config.expected)
    local winner = trimmed == self.config.expected

    if winner then
        vim.cmd("stopinsert")
    end

    return winner
end

function ReplacyLines:render()
    local cursorIdx = 6

    local lines = self.config.question_lines
    return lines, cursorIdx
end

function ReplacyLines:name()
    return "replacylines"
end

return ReplacyLines
