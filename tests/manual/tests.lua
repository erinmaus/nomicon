local lu = require "lib.luaunit"
local json = require "lib.json"
local Nomicon = require "nomicon"
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

-- test("should test tags in choice", function()
--     local story = loadStory("should_test_tags_in_choice")

--     story:continue()

--     lu.assertEquals(story:getChoiceCount(), 1)
--     lu.assertEquals(story:getTagCount(), 0)
--     lu.assertEquals(story:getChoice(1):getTag(1), "tag_one")
--     lu.assertEquals(story:getChoice(1):getTag(2), "tag_two")

--     story:choose(story:getChoice(1))

--     lu.assertEquals(story:continue(), "one three\n")
--     lu.assertEquals(story:getTagCount(), 2)
--     lu.assertEquals(story:getTag(1), "tag_one")
--     lu.assertEquals(story:getTag(-1), "tag_three")
-- end)

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
    lu.assertEquals(story:getTag(), "knot tag")

    lu.assertEquals(story:continue(), "")
    lu.assertEquals(story:getTagCount(), 1)
    lu.assertEquals(story:getTag(1), "end of knot tag")
end)

utility.runTests(tests)
