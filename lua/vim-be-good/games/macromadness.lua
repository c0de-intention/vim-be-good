local GameUtils = require("vim-be-good.game-utils")
local log = require("vim-be-good.log")
local gameLineCount = 8
local pos_target = 0
local pos_source = 0

local answer_line = ""

local MacroMadness = {}
function MacroMadness:new(difficulty, window)
    log.info("MacroMadness", difficulty, window)
    local round = {
        window = window,
        difficulty = difficulty,
    }

    self.__index = self
    return setmetatable(round, self)
end

function MacroMadness:getInstructions()
    return {
        "Use macros to make the lines match the answer.",
        "Swap: " .. pos_source .. " with: " .. pos_target,
        "Answer: " .. answer_line,
        ""
    }
end

function MacroMadness:getConfig()
    log.info("getConfig", self.difficulty, GameUtils.difficultyToTime[self.difficulty])
    local words = {}
    local word_count = 3
    local lines = GameUtils.createEmpty(gameLineCount)
    pos_target = math.random(1, 3)
    pos_source = math.random(1, 3)
    while (pos_source == pos_target) do
        pos_source = math.random(1, 3)
    end
    local answer_lines = GameUtils.createEmpty(gameLineCount)
    local start_line = 5
    local answer_line_count = 3
    for i = 1, answer_line_count do
        for _i = 1, word_count do
            local word = GameUtils.getRandomWord()
            table.insert(words, word)
        end

        local line = ""
        for _i = 1, word_count do
            if _i == pos_target then
                line = line .. words[pos_source] .. " "
            elseif _i == pos_source then
                line = line .. words[pos_target] .. " "
            else
                line = line .. words[_i] .. " "
            end
        end
        answer_line = ""
        for _i = 1, word_count do
            if _i == pos_target then
                answer_line = answer_line .. words[pos_target] .. " "
            elseif _i == pos_source then
                answer_line = answer_line .. words[pos_source] .. " "
            else
                answer_line = answer_line .. words[_i] .. " "
            end
        end
        lines[start_line + i] = line
        answer_lines[start_line + i] = answer_line
    end

    local concatenated_answer = table.concat(GameUtils.filterEmptyLines(answer_lines), "")
    self.config = {
        roundTime = GameUtils.difficultyToTime[self.difficulty] * 5,
        question_lines = lines,
        expected = concatenated_answer,
    }

    return self.config
end

function MacroMadness:checkForWin()
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

function MacroMadness:render()
    local cursorIdx = 6

    local lines = self.config.question_lines
    return lines, cursorIdx
end

function MacroMadness:name()
    return "macromadness"
end

return MacroMadness
