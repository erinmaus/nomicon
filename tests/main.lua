if love.system.getOS() == "OS X" then
    jit.off()
end

local utility = require("utility")
local isCI = utility.getIsCI(...)


local RED = "\027[31m"
local GREEN = "\027[32m"
local WHITE = "\027[0m"

local PUSH_COLORS = {
    [RED] = { 1, 0, 0, 1 },
    [GREEN] = { 0, 1, 0, 1 },
    [WHITE] = { 1, 1, 1, 1 }
}

local function printf(format, ...)
    local message = format:format(...)
    if love.system.getOS() == "Windows" then
        message = message:gsub("[\27\155][][()#;?%d]*[A-PRZcf-ntqry=><~]", "")
    end

    print(message)
end

local SUITES = {}
do
    local testSuites = love.filesystem.getDirectoryItems("/")
    for _, testSuite in ipairs(testSuites) do
        local testsFilename = string.format("%s/tests.lua", testSuite)
        if love.filesystem.getInfo(testsFilename) then
            local chunk, e = love.filesystem.load(testsFilename)

            if not chunk then
                printf("%sfailed to create test suite '%s': %s%s", RED, testsFilename, e, WHITE)
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
    local didSucceed = true
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
                    printf("%serror:%s %s", RED, WHITE, message)
                    table.insert(suite.errors, message)

                    suite.didFail = true
                elseif type(result) == "table" then
                    local status = result.success and "PASS" or "FAIL"
                    local color = result.success and GREEN or RED
                    printf("%s%s%s %s: %s %s (%.2f ms)", color, status, WHITE, suite.name, result.name or "???", (result.message and "\n" .. result.message) or "", result.executionDuration or result.totalDuration or -1)

                    table.insert(suite.tests, {
                        success = result.success or false,
                        name = result.name or "???",
                        message = result.message
                    })
                    
                    suite.didFail = suite.didFail or not result.success
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

    if key == "escape" and isDone then
        love.event.quit(returnCode)
    end
end

function love.draw()
    local coloredText = {}
    local text = {}

    local function push(color, message, ...)
        color = PUSH_COLORS[color]

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
                push(GREEN, "PASS %s -> %s", suite.name, test.name or "???")
            else
                push(RED, "FAIL %s -> %s: %s", suite.name, test.name or "???", test.message)
            end
        end
    end

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
        push(WHITE, "Press ESC to quit.")
    end

    local font = love.graphics.getFont()
    local width, height = love.graphics.getWidth(), love.graphics.getHeight()
    local _, lines = font:getWrap(table.concat(text), width - 32)

    local x = 16
    local y = 16 + -math.max(#lines * font:getHeight() - (height - 32), 0)

    love.graphics.printf(coloredText, x, y, width - 32, "left")
end
