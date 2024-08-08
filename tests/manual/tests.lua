local lu = require "lib.luaunit"
local json = require "lib.json"
local Nomicon = require "nomicon"
local Class = require "nomicon.impl.Class"
local utility = require "utility"

local tests = {}

local function loadStory(filename, ...)
    local book = json.decode(love.filesystem.read(string.format("manual/%s.json", filename)))
    local story = Nomicon.Story(book, ...)
    return story
end

local function test(description, func)
    table.insert(tests, {
        name = description,
        func = func
    })
end

test("should test default global variables", function()
    local story = loadStory("should_test_default_global_variables", { to_be_overwritten = "I'm a human bean!" })
    lu.assertEquals(story:continue(), "I'm a human bean!\n")
    lu.assertEquals(story:continue(), "Even the temp! I'm a human bean!\n")
    lu.assertEquals(story:continue(), "Now I'm financially responsible!\n")
end)

test("should test LIST_RANDOM", function()
    local story = loadStory("should_test_list_random")

    for i = 1, 10 do
        local text = story:continue()
        lu.assertIsTrue(not not text:match("^[BCD]\n$"), "test much match '^[BCD]\\n$' pattern, got " .. text)
    end
end)

test("should handle knot thread", function()
    local story = loadStory("should_handle_knot_thread")

    lu.assertEquals(story:continue(), "blah blah\n")

    lu.assertEquals(story:getChoiceCount(), 2)
    lu.assertEquals(story:getChoice(1):getText(), "option")
    lu.assertEquals(story:getChoice(2):getText(), "wigwag")

    story:choose(story:getChoice(2))

    lu.assertEquals(story:continue(), "wigwag\n")
    lu.assertEquals(story:continue(), "THE END\n")
end)

test("should test tags in choice", function()
    local story = loadStory("should_test_tags_in_choice")

    story:continue()

    lu.assertEquals(story:getChoiceCount(), 1)
    lu.assertEquals(story:getTagCount(), 0)
    lu.assertEquals(story:getChoice(1):getTag(1), "tag_one")
    lu.assertEquals(story:getChoice(1):getTag(2), "tag_two")

    story:choose(story:getChoice(1))

    lu.assertEquals(story:continue(), "one three\n")
    lu.assertEquals(story:getTagCount(), 2)
    lu.assertEquals(story:getTag(1), "tag_one")
    lu.assertEquals(story:getTag(-1), "tag_three")
end)

test("should test tags in sequence", function()
    local story = loadStory("should_test_tags_in_sequence")

    lu.assertEquals(story:continue(), "A red sequence.\n")

    lu.assertEquals(story:getTagCount(), 1)
    lu.assertEquals(story:getTag(1), "red")

    lu.assertEquals(story:continue(), "A white sequence.\n")

    lu.assertEquals(story:getTagCount(), 1)
    lu.assertEquals(story:getTag(1), "white")
end)

test("should test tags with dynamic content", function()
    local story = loadStory("should_test_tags_with_dynamic_content")

    lu.assertEquals(story:continue(), "tag\n")

    lu.assertEquals(story:getTagCount(), 1)
    lu.assertEquals(story:getTag(1), "pic8red.jpg")
end)

test("should test tags", function()
    local story = loadStory("should_test_tags")

    lu.assertEquals(story:getGlobalTagCount(), 3)
    lu.assertEquals(story:getGlobalTag(1), "author: Joe")
    lu.assertEquals(story:getGlobalTag(2), "title: My Great Story")
    lu.assertEquals(story:getGlobalTag(3), "volume: 2")

    lu.assertEquals(story:continue(), "This is the content\n")
    lu.assertEquals(story:getTagCount(), 3)
    lu.assertEquals(story:getTag(1), "author: Joe")
    lu.assertEquals(story:getTag(2), "title: My Great Story")
    lu.assertEquals(story:getTag(3), "volume: 2")

    local knotTags = story:getTags("knot")
    lu.assertEquals(knotTags, { "knot tag" })

    local stitchTags = story:getTags("knot.stitch")
    lu.assertEquals(stitchTags, { "stitch tag" })

    story:choose("knot")
    lu.assertEquals(story:continue(), "Knot content\n")
    lu.assertEquals(story:getTagCount(), 1)
    lu.assertEquals(story:getTag(1), "knot tag")

    lu.assertEquals(story:continue(), "\n")
    lu.assertEquals(story:getTagCount(), 1)
    lu.assertEquals(story:getTag(1), "end of knot tag")
end)

test("should test external functions", function()
    local story = loadStory("should_test_external_functions")

    local p = {}
    story:bindExternalFunction("set_player_name", function(players, id, name)
        players[id] = { name = name, alive = true }
    end, true, p)
    story:bindExternalFunction("is_player_alive", function(players, id)
        return players[id] and players[id].alive
    end, true, p)
    story:bindExternalFunction("get_player_name", function(players, id)
        id = id:cast(Nomicon.Constants.TYPE_NUMBER)
        return players[id] and players[id].name or "???"
    end, false, p)
    story:bindExternalFunction("kill_player", function(players, id)
        id = id:cast(Nomicon.Constants.TYPE_NUMBER)
        if players[id] then
            players[id].alive = false
        end
    end, false, p)

    lu.assertEquals(story:continue(), "So speaketh the GamePlayer 2000 XP: Whomst do you choose to be fighter FIGHTER for ROUND 1?\n")
    lu.assertEquals(story:getChoiceCount(), 2)
    lu.assertEquals(story:getChoice(1):getText(), "Player Bob-aroni")
    lu.assertEquals(story:getChoice(1):getIsSelectable(), true)
    lu.assertEquals(story:getChoice(2):getText(), "Player Bob-inator")
    lu.assertEquals(story:getChoice(2):getIsSelectable(), true)
    
    story:choose(story:getChoice(2))
    
    lu.assertEquals(story:continue(), "After playing Rippin' Rockin' Rumble!!!, Bob-inator died!\n")
    lu.assertEquals(story:continue(), "So speaketh the GamePlayer 2000 XP: Whomst do you choose to be fighter FIGHTER for ROUND 2?\n")

    lu.assertEquals(story:getChoiceCount(), 2)
    lu.assertEquals(story:getChoice(1):getText(), "Player Bob-aroni")
    lu.assertEquals(story:getChoice(1):getIsSelectable(), true)
    lu.assertEquals(story:getChoice(2):getText(), "Player Bob-inator")
    lu.assertEquals(story:getChoice(2):getIsSelectable(), false)
    
    story:choose(story:getChoice(1))
    lu.assertEquals(story:continue(), "After playing Rippin' Rockin' Rumble!!!, Bob-aroni died!\n")
    lu.assertEquals(story:continue(), "All players are dead! GAME OVER, BRUH!\n")

    lu.assertIsFalse(story:canContinue())
end)

test("should test global variable listeners", function()
    local story = loadStory("should_test_global_variables")

    local badVariableName
    story:listenForGlobalVariable("*", function(badValue, variableName, currentValue, previousValue)
        if currentValue == badValue then
            badVariableName = variableName
            return previousValue
        end

        return currentValue
    end, true, "bye")

    local example1
    story:listenForGlobalVariable("example_1", function(currentValue)
        example1 = Nomicon.Value(nil, currentValue)
    end, false)

    story:choose("the_story")
    lu.assertEquals(story:continue(), "hello world\n")
    lu.assertEquals(story:continue(), "good world\n")
    lu.assertEquals(badVariableName, "example_2")
    lu.assertTrue(Class.isDerived(Class.getType(example1), Nomicon.Value))
    lu.assertEquals(example1:getValue(), "good")
end)

test("should test function calls", function()
    local story = loadStory("should_test_function_calls")
    
    local text, tags, sum = story:call("add", true, false, 17, 115)

    lu.assertEquals(text, "Adding 17 and 115...\n")
    lu.assertEquals(tags, { "emotion: mathematical" })
    lu.assertEquals(sum, 132)
end)

test("should handle errors in function calls", function()
    local story = loadStory("should_test_function_calls")
    local success, message = pcall(story.call, story, "add", true)

    lu.assertIsFalse(success)
    lu.assertEquals(story:getCurrentFlowName(), "default")
end)

test("measure performance", function()
    local story = loadStory("performance")

    local function measure(number, expected)
        local func = coroutine.wrap(function() return story:call("print_num", true, true, number) end)

        local samples = {}
        local result, _tags, returnValue
        local before = love.timer.getTime()
        repeat
            local iterationBefore = love.timer.getTime()
            result, _tags, returnValue = func()
            local iterationAfter = love.timer.getTime()
            table.insert(samples, iterationAfter - iterationBefore)
        until result
        local after = love.timer.getTime()

        local average = 0
        for _, sample in ipairs(samples) do
            average = average + sample
        end
        average = average / #samples

        print(string.format("output: %s", result:gsub("\n", "")))
        print(string.format("average step time: %.2f ms (%d steps), total call time: %.2f ms", average * 1000, #samples, (after - before) * 1000))

        lu.assertEquals(result:gsub("\n", ""), expected)
    end

    measure(0, "zero")
    measure(1, "one")
    measure(15, "fifteen")
    measure(67, "sixty-seven")
    measure(101, "one hundred and one")
    measure(122, "one hundred and twenty-two")
    measure(222, "two hundred and twenty-two")
    measure(9745, "nine thousand seven hundred and forty-five")
    measure(3.75, "three")
end)

test("should yield", function()
    local story = loadStory("demo")

    local isEnding = false
    while story:canContinue() do
        local func = coroutine.wrap(function() return story:continue(true) end)

        local samples = {}
        local result
        local before = love.timer.getTime()
        repeat
            local iterationBefore = love.timer.getTime()
            result = func()
            local iterationAfter = love.timer.getTime()
            table.insert(samples, iterationAfter - iterationBefore)
        until result
        local after = love.timer.getTime()

        local average = 0
        for _, sample in ipairs(samples) do
            average = average + sample
        end
        average = average / #samples

        print(string.format("output: %s", result:gsub("\n", "")))
        print(string.format("average step time: %.2f ms (%d steps), total continue time: %.2f ms", average * 1000, #samples, (after - before) * 1000))

        local choices = Nomicon.ChoiceList(story)
        if choices:hasChoices() then
            for i = 1, choices:getChoiceCount() do
                local choice = choices:getChoice(i)
                if choice:getText() == "Leave the room" then
                    isEnding = true
                end

                print(string.format("choice %d: %s", i, choice:getText()))
            end

            local choice = (isEnding and choices:getChoice(2)) or (choices:getChoice(1))
            choice:choose()
        end
    end
end)

utility.runTests(tests)
