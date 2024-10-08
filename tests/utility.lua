local lu = require("lib.luaunit")
local json = require("lib.json")
local Nomicon = require("nomicon")

local IS_DEBUG = os.getenv("LOCAL_LUA_DEBUGGER_VSCODE") == "1"

local function getIsCI(...)
    if os.getenv("CI") then
        return true
    end

    for i = 1, select("#", ...) do
        arg = select(i, ...)
        arg = type(arg) == "string" and arg:lower()

        if arg == "ci=yes" then
            return true
        elseif arg == "ci=no" then
            return false
        end
    end
end

local function collectTests(path, pattern)
    local tests = {}
    local filenames = love.filesystem.getDirectoryItems(path)
    table.sort(filenames)

    for _, filename in ipairs(filenames) do
        local testName = filename:match("^(.*)%.json$")
        local niceName = testName and testName:gsub("_", " ")

        if  niceName and (not pattern or  niceName:match(pattern)) then
            local test = {
                name = niceName,
                book = json.decode(love.filesystem.read(string.format("%s/%s", path, filename))),
                content = love.filesystem.read(string.format("%s/%s.txt", path, testName)) or "",
                choicePoints = {},
                currentChoicePoint = 0
            }

            do
                local choicesFilename = string.format("%s/%s.choices.txt", path, testName)
                if love.filesystem.getInfo(choicesFilename) then
                    local lineNumber = 0
                    local choices

                    local choicesRemaining = 0
                    for line in love.filesystem.lines(choicesFilename) do
                        lineNumber = lineNumber + 1
                        if line:match("^(%d+)$") and choicesRemaining == 0 then
                            if choices then
                                table.insert(test.choicePoints, choices)
                            end

                            choicesRemaining = tonumber(line) or 0
                            choices = { n = choicesRemaining }
                        elseif choices then
                            choicesRemaining = choicesRemaining - 1
                            table.insert(choices, line)
                        else
                            error(string.format("malformed choices for test '%s' line %d", testName, lineNumber))
                        end
                    end

                    if choices then
                        table.insert(test.choicePoints, choices)
                    end
                end

                table.insert(tests, test)
            end
        end
    end

    return tests
end

local function runTest(test)
    local story = Nomicon.Story(test.book)
    lu.assertEquals(story:canContinue(), true)

    local maxTime = love.timer.getTime() + 1
    if not IS_DEBUG then
        debug.sethook(function()
            if love.timer.getTime() > maxTime then
                error(debug.traceback(string.format("TIMEOUT: %s", test.name or "???"), 2), 2)
            end
        end, "l")
    end

    local j = 1
    local currentText = ""
    local currentChoicePoint = 1
    local before = love.timer.getTime()
    while story:canContinue() and (test.content and j < #test.content) do
        local text = story:continue()
        lu.assertEquals(text, story:getText())

        currentText = currentText .. text

        if test.content then
            local fragment = test.content:sub(j)
            local nextI, nextJ = fragment:find(text, 1, true)
            if not (nextI and nextJ) or nextI ~= 1 then
                lu.assertEquals(text, fragment:match("(.*)\n"), "output text must match expected text")
            else
                j = j + nextJ
            end
        end

        if story:hasChoices() then
            if currentChoicePoint > test.currentChoicePoint and currentChoicePoint < #test.choicePoints then
                local choicePoint = test.choicePoints[currentChoicePoint]
                currentChoicePoint = currentChoicePoint + 1

                local choiceCount = 0
                local firstChoice
                for i = 1, story:getChoiceCount() do
                    if story:getChoice(i):getIsSelectable() and not story:getChoice(i):getChoicePoint():getIsInvisibleDefault() then
                        choiceCount = choiceCount + 1
                        firstChoice = firstChoice or story:getChoice(i)
                    end
                end

                lu.assertEquals(choiceCount, choicePoint.n, "choice count mismatch")

                local choicePointIndex = 0
                for i = 1, story:getChoiceCount() do
                    local choice = story:getChoice(i)
                    if choice:getIsSelectable() and not choice:getChoicePoint():getIsInvisibleDefault() then
                        choicePointIndex = choicePointIndex + 1
                        if choicePoint[choicePointIndex] ~= "" then
                            lu.assertEquals(choice:getText(), choicePoint[choicePointIndex], "choice text mismatch")
                        end
                    end
                end

                local success = story:choose(firstChoice)
                lu.assertEquals(success, true, "must succeed with first choice")
            else
                local choices = Nomicon.ChoiceList(story)
                if choices:hasChoices() then
                    local success = choices:getChoice(1):choose()
                    lu.assertEquals(success, true, "must succeed with first choice")
                end
            end
        end
    end
    local after = love.timer.getTime()

    if test.content and j < #test.content then
        lu.assertEquals(currentText, test.content, "output text must match ALL expected text")
    end

    if not IS_DEBUG then
        debug.sethook()
    end

    return { duration = after - before }
end

local function runTests(tests)
    for _, test in ipairs(tests) do
        local success, result
        local before = love.timer.getTime()
        if test.func then
            success, result = xpcall(test.func, debug.traceback)
        else
            success, result = xpcall(runTest, debug.traceback, test)
        end
        local after = love.timer.getTime()

        if not success then
            result = result or ""
            if result:find("LuaUnit") then
                coroutine.yield({
                    success = false,
                    name = test.name,
                    result = result:match("(.*)stack traceback:"):gsub("(LuaUnit test %w+:%s*)", ""),
                    duration = (after - before) * 1000
                })
            else
                error(result)
            end
        else
            coroutine.yield({
                success = true,
                name = test.name,
                totalDuration = (after - before) * 1000,
                executionDuration = result and (result.duration * 1000) or nil
            })
        end
    end
end

return {
    getIsCI = getIsCI,
    collectTests = collectTests,
    runTests = runTests
}
