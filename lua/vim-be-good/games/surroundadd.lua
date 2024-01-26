local GameUtils = require("vim-be-good.game-utils")
local log = require("vim-be-good.log")
local gameLineCount = 5

local instructions = {
    "add curly brackets around the words to make a json object.",
}

local SurroundAdd = {}
function SurroundAdd:new(difficulty, window)
    log.info("NewWords", difficulty, window)
    local round = {
        window = window,
        difficulty = difficulty,
    }

    self.__index = self
    return setmetatable(round, self)
end

function SurroundAdd:getInstructions()
    return instructions
end

function SurroundAdd:getConfig()
    log.info("getConfig", self.difficulty, GameUtils.difficultyToTime[self.difficulty])

    local one = GameUtils.getRandomWord()
    local two = GameUtils.getRandomWord()
    local round = {}
    local expected = {}
    -- question looks like: "oar" : "qar"
    local question = "\"" .. one .. "\" : \"" .. two .. "\""
    -- answer looks like: {"oar":"qar"}
    local answer = "{\"" .. one .. "\":\"" .. two .. "\"}"
    table.insert(round, question);
    table.insert(expected, answer)
    self.config = {
        roundTime = GameUtils.difficultyToTime[self.difficulty],
        words = round,
        expected = table.concat(expected, "")
    }

    return self.config
end

function SurroundAdd:checkForWin()
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

function SurroundAdd:render()
    local lines = GameUtils.createEmpty(gameLineCount)
    local cursorIdx = 5

    lines[5] = table.concat(self.config.words, " ")

    return lines, cursorIdx
end

function SurroundAdd:name()
    return "surroundadd"
end

return SurroundAdd
