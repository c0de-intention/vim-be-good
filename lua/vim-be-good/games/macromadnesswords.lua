local GameUtils = require("vim-be-good.game-utils")
local log = require("vim-be-good.log")
local gameLineCount = 8
local increment = 0
local start_line = 5


local MacroMadnessWords = {}
function MacroMadnessWords:new(difficulty, window)
    log.info("MacroMadnessWords", difficulty, window)
    local round = {
        window = window,
        difficulty = difficulty,
    }

    self.__index = self
    return setmetatable(round, self)
end

function MacroMadnessWords:getInstructions()
    if increment == 1 then
        return {
            "Use macros to change every word to bar.",
            ""
        }
    elseif increment == 2 then
        return {
            "Use macros to change every second word to bar.",
            ""
        }
    elseif increment == 3 then
        return {
            "Use macros to change every third word to bar.",
            ""
        }
    end
end

function MacroMadnessWords:getConfig()
    log.info("getConfig", self.difficulty, GameUtils.difficultyToTime[self.difficulty])
    local word_count = math.random(5, 10)
    local lines = GameUtils.createEmpty(gameLineCount)
    local answer_lines = GameUtils.createEmpty(gameLineCount)
    local start_line = 5
    increment = math.random(1, 3)
    local line = ""
    local answer_line = ""
    local correct_word = "bar"
    local fill_word = "foo"
    local wrong_word = ""
    for i = 1, word_count do
        wrong_word = GameUtils.getRandomWord()
        while wrong_word == correct_word or wrong_word == fill_word do
            wrong_word = GameUtils.getRandomWord()
        end
        if i % increment == 0 then
            -- handle even
            line = line .. wrong_word .. " "
            answer_line = answer_line .. correct_word .. " "
        else
            -- handle odd
            line = line .. fill_word .. " "
            answer_line = answer_line .. fill_word .. " "
        end
    end
    lines[start_line] = line
    answer_lines[start_line] = answer_line

    local concatenated_answer = table.concat(GameUtils.filterEmptyLines(answer_lines), "")
    self.config = {
        roundTime = GameUtils.difficultyToTime[self.difficulty] * 4,
        question_lines = lines,
        expected = concatenated_answer,
    }

    return self.config
end

function MacroMadnessWords:checkForWin()
    local lines = self.window.buffer:getGameLines()
    local trimmed_lines = GameUtils.trimLines(lines)
    local concatenated = table.concat(GameUtils.filterEmptyLines(trimmed_lines), "")
    local lowercased = concatenated:lower()
    local trimmed = lowercased:gsub("%s+", "")
    local answer_trimmed = self.config.expected:gsub("%s+", "")
    print('trimmed', trimmed, 'expected', answer_trimmed)
    local winner = trimmed == answer_trimmed

    if winner then
        vim.cmd("stopinsert")
    end

    return winner
end

function MacroMadnessWords:render()
    local cursorIdx = start_line

    local lines = self.config.question_lines
    return lines, cursorIdx
end

function MacroMadnessWords:name()
    return "MacroMadnessWords"
end

return MacroMadnessWords
