local lu = require("lib.luaunit")
local json = require("lib.json")
local Nomicon = require("nomicon")

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

    local j = 1
    local currentText = ""
    local currentChoicePoint = 1
    while story:canContinue() and (test.content and j < #test.content) do
        local text = story:continue()
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

    if test.content and j < #test.content then
        lu.assertEquals(currentText, test.content, "output text must match ALL expected text")
    end
end

local function runTests(tests)
    for _, test in ipairs(tests) do
        local success, message
        if test.func then
            success, message = xpcall(test.func, debug.traceback)
        else
            success, message = xpcall(runTest, debug.traceback, test)
        end

        if not success then
            message = message or ""
            if message:find("LuaUnit") or true then
                coroutine.yield({
                    success = false,
                    name = test.name,
                    message = message:match("(.*)stack traceback:"):gsub("(LuaUnit test %w+:%s*)", "")
                })
            else
                error(message)
            end
        else
            coroutine.yield({
                success = true,
                name = test.name
            })
        end
    end
end

return {
    getIsCI = getIsCI,
    collectTests = collectTests,
    runTests = runTests
}
