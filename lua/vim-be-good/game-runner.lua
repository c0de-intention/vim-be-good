local bind = require("vim-be-good.bind");
local types = require("vim-be-good.types");
local GameUtils = require("vim-be-good.game-utils");
local RelativeRound = require("vim-be-good.games.relative");
local WordRound = require("vim-be-good.games.words");
local SurroundAdd = require("vim-be-good.games.surroundadd");
local SurroundChange = require("vim-be-good.games.surroundchange");
local SurroundRemove = require("vim-be-good.games.surroundremove");
local Swapsy = require("vim-be-good.games.swapsy");
local ReplacyWords = require("vim-be-good.games.replacywords");
local ReplacyLines = require("vim-be-good.games.replacylines");
local MacroMadnessLines = require("vim-be-good.games.macromadnesslines");
local MacroMadnessWords = require("vim-be-good.games.macromadnesswords");
local TextObjectStorm = require("vim-be-good.games.textobjectstorm");
local GlobalOps = require("vim-be-good.games.globalops");
local ArgReorder = require("vim-be-good.games.argreorder");
local CiRound = require("vim-be-good.games.ci");
local HjklRound = require("vim-be-good.games.hjkl");
local WhackAMoleRound = require("vim-be-good.games.whackamole");
local log = require("vim-be-good.log");
local statistics = require("vim-be-good.statistics");

Stats = statistics:new()

local endStates = {
    menu = "Menu",
    replay = "Replay",
    quit = "Quit (or just ZZ like a real man)",
}

local states = {
    playing = 1,
    gameEnd = 2,
}

local successAdvanceDelayMs = {
    noob = 5000,
}
local noobSkipLine = "# NOOB: delete this line to skip level"

local games = {
    ["ci{"] = function(difficulty, window)
        return CiRound:new(difficulty, window)
    end,

    relative = function(difficulty, window)
        return RelativeRound:new(difficulty, window)
    end,

    words = function(difficulty, window)
        return WordRound:new(difficulty, window)
    end,

    surroundadd = function(difficulty, window)
        return SurroundAdd:new(difficulty, window)
    end,

    surroundchange = function(difficulty, window)
        return SurroundChange:new(difficulty, window)
    end,

    replacywords = function(difficulty, window)
        return ReplacyWords:new(difficulty, window)
    end,

    replacylines = function(difficulty, window)
        return ReplacyLines:new(difficulty, window)
    end,

    macromadnesslines = function(difficulty, window)
        return MacroMadnessLines:new(difficulty, window)
    end,

    macromadnesswords = function(difficulty, window)
        return MacroMadnessWords:new(difficulty, window)
    end,

    textobjectstorm = function(difficulty, window)
        return TextObjectStorm:new(difficulty, window)
    end,

    globalops = function(difficulty, window)
        return GlobalOps:new(difficulty, window)
    end,

    argreorder = function(difficulty, window)
        return ArgReorder:new(difficulty, window)
    end,

    surroundremove = function(difficulty, window)
        return SurroundRemove:new(difficulty, window)
    end,

    swapsy = function(difficulty, window)
        return Swapsy:new(difficulty, window)
    end,

    hjkl = function(difficulty, window)
        return HjklRound:new(difficulty, window)
    end,

    whackamole = function(difficulty, window)
        return WhackAMoleRound:new(difficulty, window)
    end,
}

local runningId = 0
local gameHints = {
    ["ci{"] = "Use text objects: ci{ / ci[ to replace inside delimiters quickly.",
    relative = "Use relative jumps like 10j, 5k, gg/G, then delete the target line.",
    words = "Use motions plus delete (dw, dW, de, db) to remove only the odd word.",
    surroundadd = "Use surround/text-object style edits to add braces efficiently.",
    surroundchange = "Use surround change (cs'\\\") or text objects to swap quote style.",
    surroundremove = "Use surround delete (ds]) or precise text-object deletes.",
    swapsy = "Use text objects and put motions to swap values quickly.",
    replacywords = "Use change/replace flows (cw, caw, r) and repeat with . when possible.",
    replacylines = "Use linewise changes and repeat (cc, C, .) instead of full retyping.",
    macromadnesslines = "Record a macro (qq ... q) and replay with @q to batch the same edit.",
    macromadnesswords = "Record once, replay many times: macros are the fastest path here.",
    textobjectstorm = "Text objects are fastest: ci\\\", ci(, ci[, ci{ and then repeat with .",
    hjkl = "Navigate only with h/j/k/l and delete with x.",
    whackamole = "Jump to the caret target quickly, then toggle its case (~) to finish.",
    globalops = "Use :g / :v batch operations; press g? again to re-open this hint.",
    argreorder = "Use f/F/t motions plus d/p or text objects to reorder args with minimal moves.",
}

local GameRunner = {}

local function getGame(game, difficulty, window)
    log.info("getGame", game, difficulty, window)
    return games[game](difficulty, window)
end

local function getRoundHint(round)
    if round and round.config and round.config.hint then
        return round.config.hint
    end

    local roundName = round:name()
    return gameHints[roundName]
end

local function wrapText(text, maxWidth)
    if not text or text == "" then
        return text
    end

    maxWidth = maxWidth or 72
    local lines = {}
    local current = ""

    for word in string.gmatch(text, "%S+") do
        while vim.fn.strdisplaywidth(word) > maxWidth do
            local head = string.sub(word, 1, maxWidth - 1)
            if current ~= "" then
                table.insert(lines, current)
                current = ""
            end
            table.insert(lines, head)
            word = string.sub(word, maxWidth)
        end

        local candidate = current == "" and word or (current .. " " .. word)
        if vim.fn.strdisplaywidth(candidate) <= maxWidth then
            current = candidate
        else
            if current ~= "" then
                table.insert(lines, current)
            end
            current = word
        end
    end

    if current ~= "" then
        table.insert(lines, current)
    end

    return table.concat(lines, "\n")
end

local function getHintWrapWidth()
    local cols = vim.o.columns or 120
    local adaptive = math.floor(cols * 0.30)
    if adaptive < 24 then
        return 24
    end
    if adaptive > 40 then
        return 40
    end
    return adaptive
end

-- games table, difficulty string
function GameRunner:new(selectedGames, difficulty, window, onFinished)
    log.info("New", difficulty)
    local config = {
        difficulty = difficulty,
        roundCount = GameUtils.getRoundCount(difficulty),
    }

    local rounds = {}
    log.info("GameRunner:new", vim.inspect(selectedGames))

    if selectedGames[1] == "random" then
        selectedGames = {}
        for idx = 1, #types.games - 1 do
            table.insert(selectedGames, types.games[idx])
        end
        log.info("GameRunner:new - random selected", vim.inspect(selectedGames))
    end

    for idx = 1, #selectedGames do
        table.insert(rounds, getGame(selectedGames[idx], difficulty, window))
    end

    local gameRunner = {
        currentRound = 1,
        rounds = rounds,
        config = config,
        window = window,
        onFinished = onFinished,
        results = {
            successes = 0,
            failures = 0,
            timings = {},
            games = {},
        },
        state = states.playing
    }

    self.__index = self
    local game = setmetatable(gameRunner, self)

    local function onChange()
        if hasEverythingEnded then
            if not self.ended then
                self:close()
            end
            return
        end

        log.info("onChange", game.state, states.playing)

        if game.state == states.playing then
            game:checkForWin()
        else
            game:checkForNext()
        end
    end

    game.onChange = onChange
    window.buffer:onChange(onChange)
    return game
end

function GameRunner:countdown(count, cb)
    local self = self
    ok, msg = pcall(function()
        if count > 0 then
            local str = string.format("Game Starts in %d", count)

            self.window.buffer:debugLine(str)
            self.window.buffer:render({})

            vim.defer_fn(function()
                self:countdown(count - 1, cb)
            end, 1000)
        else
            cb()
        end
    end)

    if not ok then
        log.info("Error: GameRunner#countdown", msg)
    end
end

function GameRunner:init()
    local self = self

    vim.schedule(function()
        self.window.buffer:setInstructions({})
        self.window.buffer:clear()
        self:countdown(3, function() self:run() end)
    end)
end

function GameRunner:checkForNext()
    log.info("GameRunner:checkForNext")

    local lines = self.window.buffer:getGameLines()
    local expectedLines, optionLine = self:renderEndGame()
    local idx = 0
    local found = false

    repeat
        idx = idx + 1
        found = lines[idx] ~= expectedLines[idx]
    until idx == #lines or found

    if found == false then
        return
    end

    local item = expectedLines[idx]

    log.info("GameRunner:checkForNext: compared", vim.inspect(lines), vim.inspect(expectedLines))
    log.info("GameRunner:checkForNext: deleted line is", item,
        item == endStates.menu,
        item == endStates.replay,
        item == endStates.quit)

    local foundKey = nil
    for k, v in pairs(endStates) do
        log.info("pairs", k, v, item)
        if item == v then
            foundKey = k
        end
    end

    -- todo implement this correctly....
    if foundKey then
        self.onFinished(self, foundKey)
    else
        log.info("GameRunner:checkForNext Some line was changed that is insignificant, rerendering")
        self.window.buffer:render(expectedLines)
    end
end

function GameRunner:checkForWin()
    log.info("GameRunner:checkForWin", self.round, self.running)
    if not self.round then
        return
    end

    if not self.running then
        return
    end

    if self.config.difficulty == "noob" and self.skipLine then
        local allLines = vim.api.nvim_buf_get_lines(self.window.bufh, 0, -1, false)
        local foundSkipLine = false
        for _, line in ipairs(allLines) do
            if line == self.skipLine then
                foundSkipLine = true
                break
            end
        end

        if not foundSkipLine then
            self:endRound(true)
            return
        end
    end

    if not self.round:checkForWin() then
        return
    end

    self:endRound(true)
end

function GameRunner:endRound(success)
    success = success or false

    self.running = false
    if success then
        self.results.successes = self.results.successes + 1
    else
        self.results.failures = self.results.failures + 1
    end

    local endTime = GameUtils.getTime()
    local totalTime = endTime - self.startTime
    table.insert(self.results.timings, totalTime)
    table.insert(self.results.games, self.round:name())

    local result = {
        timestamp = vim.fn.localtime(),
        roundNum = self.currentRound,
        difficulty = self.round.difficulty,
        roundName = self.round:name(),
        success = success,
        time = totalTime,
    }
    Stats:logResult(result)
    log.info("endRound", self.currentRound, self.config.roundCount)
    if self.currentRound >= self.config.roundCount then -- TODO: self.config.roundCount then
        self:endGame()
        return
    end
    self.currentRound = self.currentRound + 1

    if not self.window:isValid() then
        return
    end

    local delayMs = 0
    if success then
        delayMs = successAdvanceDelayMs[self.config.difficulty] or 0
    end

    if success and delayMs > 0 then
        vim.notify("Level Complete!", vim.log.levels.INFO, {
            title = "vim-be-good",
            timeout = 3000,
        })
    end

    if delayMs > 0 then
        vim.defer_fn(function()
            if self.window:isValid() then
                vim.schedule_wrap(function() self:run() end)()
            end
        end, delayMs)
    else
        vim.schedule_wrap(function() self:run() end)()
    end
end

function GameRunner:close()
    log.info("GameRunner:close()", debug.traceback())
    self.window.buffer:removeListener(self.onChange)
    self.ended = true
end

function GameRunner:renderEndGame()
    self.window.buffer:debugLine(string.format(
        "Round %d / %d", self.currentRound, self.config.roundCount))

    local lines = {}
    local sum = 0

    for idx = 1, #self.results.timings do
        sum = sum + self.results.timings[idx]
    end

    self.ended = true

    -- TODO: Make this a bit better especially with random.
    table.insert(lines, string.format("%d / %d completed successfully", self.results.successes, self.config.roundCount))
    table.insert(lines, string.format("Average %.2f", sum / self.config.roundCount))
    table.insert(lines, string.format("Game Type %s", self.results.games[1]))

    for idx = 1, 3 do
        table.insert(lines, "")
    end

    table.insert(lines, "Where do you want to go next? (Delete Line)")
    local optionLine = #lines + 1

    table.insert(lines, "Menu")
    table.insert(lines, "Replay")
    table.insert(lines, "Quit (or just ZZ like a real man)")

    return lines, optionLine
end

function GameRunner:endGame()
    local lines = self:renderEndGame()
    self.state = states.gameEnd
    self.window.buffer:setInstructions({})
    self.window.buffer:render(lines)
end

function GameRunner:run()
    local idx = math.random(1, #self.rounds)
    self.round = self.rounds[idx]

    local roundConfig = self.round:getConfig()
    log.info("RoundName:", self.round:name())
    local roundHint = getRoundHint(self.round)

    self.window.buffer:debugLine(string.format(
        "Round %d / %d", self.currentRound, self.config.roundCount))

    local roundInstructions = vim.deepcopy(self.round.getInstructions())
    self.skipLine = nil
    if self.config.difficulty == "noob" then
        self.skipLine = noobSkipLine
        table.insert(roundInstructions, "")
        table.insert(roundInstructions, self.skipLine)
    end

    self.window.buffer:setInstructions(roundInstructions)
    local lines, cursorLine, cursorCol = self.round:render()
    self.window.buffer:render(lines)

    local bufnr = self.window and self.window.bufh or 0
    if bufnr ~= 0 then
        vim.keymap.set("n", "g?", function()
            if roundHint then
                vim.notify(wrapText(roundHint, getHintWrapWidth()), vim.log.levels.INFO, {
                    title = "vim-be-good hint",
                    timeout = 10000,
                })
            else
                vim.notify("No hint for this round.", vim.log.levels.INFO, {
                    title = "vim-be-good hint",
                    timeout = 4000,
                })
            end
        end, { buffer = bufnr, silent = true, desc = "VimBeGood hint" })
    end

    cursorLine = cursorLine or 0
    cursorCol = cursorCol or 0

    local instuctionLen = #self.round.getInstructions()
    local curRoundLineLen = 1
    cursorLine = cursorLine + curRoundLineLen + instuctionLen

    log.info("Setting current line to", cursorLine, cursorCol)
    if cursorLine > 0 then
        vim.api.nvim_win_set_cursor(0, { cursorLine, cursorCol })
    end

    -- Keep instructions visible on noob without overriding gameplay cursor target.
    if self.config.difficulty == "noob" then
        vim.fn.winrestview({ topline = 1, leftcol = 0 })
    end

    self.startTime = GameUtils.getTime()

    runningId = runningId + 1
    local currentId = runningId
    self.running = true

    log.info("defer_fn", roundConfig.roundTime)
    vim.defer_fn(function()
        if self.state == states.gameEnd then
            return
        end
        log.info("Deferred?", currentId, runningId)
        if currentId < runningId then
            return
        end

        self:endRound()
    end, roundConfig.roundTime)
end

return GameRunner
