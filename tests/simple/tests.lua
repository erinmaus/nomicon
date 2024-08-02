local lu = require("lib.luaunit")
local json = require("lib.json")
local Nomicon = require "nomicon"

local TESTS = {}
do
    local filenames = love.filesystem.getDirectoryItems("simple")
    table.sort(filenames)

    for _, filename in ipairs(filenames) do
        local testName = filename:match("^(.*)%.json$")

        if testName and testName:find("function") then
            local test = {
                 name = testName:gsub("_", " "),
                 book = json.decode(love.filesystem.read(string.format("simple/%s", filename))),
                 content = love.filesystem.read(string.format("simple/%s.txt", testName)) or "",
            }

            table.insert(TESTS, test)
        end
    end
end

local function runTest(test)
    local story = Nomicon.Story(test.book)
    lu.assertEquals(story:canContinue(), true)

    local j = 1
    local currentText = ""
    while story:canContinue() and (test.content and j < #test.content) do
        local text = story:continue()
        currentText = currentText .. text

        if test.content then
            local fragment = test.content:sub(j)
            local nextI, nextJ = fragment:find(text, 1, true)
            if not (nextI and nextJ) or nextI ~= 1 then
                lu.assertEquals(text, fragment:match("(.*)\n"), "output text must match expected text")
            else
                j = nextJ + 1
            end
        end
    end

    if test.content and j < #test.content then
        lu.assertEquals(currentText, test.content, "output text must match ALL expected text")
    end
end

for _, test in ipairs(TESTS) do
    local success, message = xpcall(runTest, debug.traceback, test)
    if not success then
        if message and message:find("LuaUnit") then
            coroutine.yield({
                success = false,
                name = test.name,
                message = message:match("^LuaUnit.*:%s*.*\n")
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
