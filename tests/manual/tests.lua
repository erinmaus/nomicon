local lu = require "lib.luaunit"
local json = require "lib.json"
local Nomicon = require "nomicon"
local Class = require "nomicon.impl.Class"
local utility = require "utility"

local tests = {}

local function loadStory(filename)
    local book = json.decode(love.filesystem.read(string.format("manual/%s.json", filename)))
    local story = Nomicon.Story(book)
    return story
end

local function test(description, func)
    table.insert(tests, {
        name = description,
        func = func
    })
end

test("should test LIST_RANDOM", function()
    local story = loadStory("should_test_list_random")

    for i = 1, 10 do
        local text = story:continue()
        lu.assertIsTrue(not not text:match("^[BCD]\n$"), "test much match '^[BCD]\\n$' pattern, got " .. text)
    end
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

    lu.assertEquals(story:continue(), "")
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
        
    story:continue()
    lu.assertEquals(story:getChoiceCount(), 2)
    lu.assertEquals(story:getChoice(1):getText(), "Player Bob-aroni")
    lu.assertEquals(story:getChoice(1):getIsSelectable(), true)
    lu.assertEquals(story:getChoice(2):getText(), "Player Bob-inator")
    lu.assertEquals(story:getChoice(2):getIsSelectable(), true)
    
    story:choose(story:getChoice(2))
    
    lu.assertEquals(story:continue(), "After playing Rippin' Rockin' Rumble!!!, Bob-inator died!\n")
    lu.assertEquals(story:continue(), "So speaketh the GamePlayer 2000 XP: Whomst do you choose to be fighter FIGHTER for ROUND 2?\n")

    story:continue()
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

utility.runTests(tests)
