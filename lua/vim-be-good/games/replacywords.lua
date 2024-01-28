local GameUtils = require("vim-be-good.game-utils")
local log = require("vim-be-good.log")
local gameLineCount = 5

local instructions = {
    "Replace the other words with the first word.",
}

local ReplacyWords = {}
function ReplacyWords:new(difficulty, window)
    log.info("NewReplacyWords", difficulty, window)
    local round = {
        window = window,
        difficulty = difficulty,
    }

    self.__index = self
    return setmetatable(round, self)
end

function ReplacyWords:getInstructions()
    return instructions
end

function ReplacyWords:getConfig()
    log.info("getConfig", self.difficulty, GameUtils.difficultyToTime[self.difficulty])

    local correct_word = GameUtils.getRandomWord()
    local wrong_word = "replace_me"
    local round = {}
    local expected = {}
    -- question looks like:
    -- oar
    -- replace_me
    -- replace_me
    -- TODO: make this dynamic
    local question_ln_1 = correct_word
    local question_ln_2 = wrong_word
    local question_ln_3 = wrong_word

    table.insert(round, question_ln_1);
    table.insert(round, question_ln_2);
    table.insert(round, question_ln_3);
    -- answer looks like:
    -- oar
    -- oar
    -- oar
    local answer_ln_1 = correct_word
    local answer_ln_2 = correct_word
    local answer_ln_3 = correct_word
    table.insert(expected, answer_ln_1)
    table.insert(expected, answer_ln_2)
    table.insert(expected, answer_ln_3)
    self.config = {
        roundTime = GameUtils.difficultyToTime[self.difficulty],
        words = round,
        expected = table.concat(expected, "")
    }

    return self.config
end

function ReplacyWords:checkForWin()
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

function ReplacyWords:render()
    local lines = GameUtils.createEmpty(gameLineCount)
    local cursorIdx = 5

    lines[5] = table.concat(self.config.words, " ")

    return lines, cursorIdx
end

function ReplacyWords:name()
    return "replacywords"
end

return ReplacyWords
