local GameUtils = require("vim-be-good.game-utils")
local log = require("vim-be-good.log")
local gameLineCount = 5

local instructions = {
    "swap the single quotation marks for double quotation marks to make a json object.",
}

local SurroundChange = {}
function SurroundChange:new(difficulty, window)
    log.info("NewWords", difficulty, window)
    local round = {
        window = window,
        difficulty = difficulty,
    }

    self.__index = self
    return setmetatable(round, self)
end

function SurroundChange:getInstructions()
    return instructions
end

function SurroundChange:getConfig()
    log.info("getConfig", self.difficulty, GameUtils.difficultyToTime[self.difficulty])

    local one = GameUtils.getRandomWord()
    local two = GameUtils.getRandomWord()
    local round = {}
    local expected = {}
    -- question looks like: "oar" : "qar"
    local question = "{\"" .. one .. "\" : \'" .. two .. "\'}"
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

function SurroundChange:checkForWin()
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

function SurroundChange:render()
    local lines = GameUtils.createEmpty(gameLineCount)
    local cursorIdx = 5

    lines[5] = table.concat(self.config.words, " ")

    return lines, cursorIdx
end

function SurroundChange:name()
    return "surroundchange"
end

return SurroundChange
