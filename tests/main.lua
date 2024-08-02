package.path = string.format("%s/?.lua;%s/?/init.lua", love.filesystem.getSourceBaseDirectory(), love.filesystem.getSourceBaseDirectory())

local utility = require("utility")
local isCI = utility.getIsCI(...)

local SUITES = {}
do
    local testSuites = love.filesystem.getDirectoryItems("/")
    for _, testSuite in ipairs(testSuites) do
        local testsFilename = string.format("%s/tests.lua", testSuite)
        if love.filesystem.getInfo(testsFilename) then
            local chunk, e = love.filesystem.load(testsFilename)

            if isCI and not chunk then
                print("failed to create test suite '%s': %s", testsFilename, e)
            end

            table.insert(SUITES, {
                name = testSuite,
                chunk = chunk,
                thread = chunk and coroutine.create(chunk),
                errors = { e },
                tests = {},
                isDone = not chunk,
                didFail = not chunk,
                time = 0
            })
        end
    end
end

local FRAME = 1 / 60

function love.update()
    local startTime = isCI and math.huge or love.timer.getTime()
    local didSucceed = false
    local isDone = false

    local currentTime = love.timer.getTime()
    for _, suite in ipairs(SUITES) do
        if not suite.isDone then
            while (startTime == math.huge or currentTime < startTime + FRAME) and not suite.isDone do
                local beforeTime = love.timer.getTime()
                local success, result = coroutine.resume(suite.thread)
                local afterTime = love.timer.getTime()
                
                if not success then
                    local message = debug.traceback(suite.thread, string.format("error: %s", result))
                    if isCI then
                        print(message)
                    else
                        table.insert(suite.errors, message)
                    end

                    suite.didFail = true
                elseif type(result) == "table" then
                    if isCI then
                        local status = result.success and "PASS" or "FAIL"
                        print(string.format("%s %s: %s", status, suite.name, result.name or "???"))
                    else
                        table.insert(suite.tests, {
                            success = result.success or false,
                            name = result.name or "???",
                            message = result.message
                        })
                        
                        suite.didFail = suite.didFail or not result.success
                    end
                end
                
                if coroutine.status(suite.thread) == "dead" then
                    suite.isDone = true
                end
                
                suite.time = suite.time + (afterTime - beforeTime)
            end
        end

       didSucceed = didSucceed and not suite.didFail
       isDone = isDone and suite.isDone
    end
    
    if isCI and not isDone then
        if not didSucceed then
            love.event.quit(1)
        else
            love.event.quit(0)
        end
    end
end

function love.keypressed(key)
    local returnCode = 0
    local isDone = true
    for _, suite in ipairs(SUITES) do
        isDone = isDone and suite.isDone
        if suite.didFail then
            returnCode = 1
        end
    end

    if isDone then
        love.event.quit(returnCode)
    end
end

local RED = { 1, 0, 0, 1 }
local GREEN = { 0, 1, 0, 1 }
local WHITE = { 1, 1, 1, 1 }

function love.draw()
    local coloredText = {}
    local text = {}

    local function push(color, message, ...)
        local t = string.format(message, ...) .. "\n"
        table.insert(text, t)

        table.insert(coloredText, color or WHITE)
        table.insert(coloredText, t)
    end

    push(WHITE, "Running %d suites...", #SUITES)

    local isRunning = #SUITES > 0
    local isGreen = true
    for _, suite in ipairs(SUITES) do
        isRunning = isRunning and not suite.isDone

        if suite.didFail then
            isGreen = false
            push(RED, "Suite '%s' failed! %d tests completed.", suite.name, #suite.tests)
        elseif suite.isDone then
            push(GREEN, "Suite '%s' passed! %d tests completed.", suite.name, #suite.tests)
        else
            push(WHITE, "Suite '%s' running... %d tests completed.", suite.name, #suite.tests)
        end

        for _, test in ipairs(suite.tests) do
            if test.success then
                push(GREEN, "PASS %s", test.name or "???")
            else
                push(RED, "FAIL %s: %s", test.name or "???", test.message)
            end
        end
    end

    if not isRunning then
        local color = isGreen and GREEN or RED
        local status = isGreen and "PASS" or "FAIL"

        push(color, "%s: ran %d suites", status, #SUITES)
    end

    for _, suite in ipairs(SUITES) do
        for _, error in ipairs(suite.errors) do
            push(RED, "%s", error)
        end
    end

    if not isRunning then
        push(WHITE, "Press any key to quit.")
    end

    local font = love.graphics.getFont()
    local width, height = love.graphics.getWidth(), love.graphics.getHeight()
    local _, lines = font:getWrap(table.concat(text), width - 32)

    local x = 16
    local y = 16 + -math.max(#lines * font:getHeight() - (height - 32), 0)

    love.graphics.printf(coloredText, x, y, width - 32, "left")
end
