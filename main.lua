local json = require "tests.lib.json"
local Nomicon = require "nomicon"

--- @type Nomicon.Story
local story

--- @type Nomicon.ChoiceList
local choices

--- @type string
local text

local currentChoiceIndex = 1

local DIALOG_WIDTH = 400

function love.load()
    love.graphics.setNewFont(24)
end

function love.keypressed(key)
    if key == "escape" then
        love.event.quit()
    end

    if not (story and choices) then
        return
    end

    if key == "return" then
        if choices:hasChoices() then
            choices:getChoice(currentChoiceIndex):choose()
        end

        if story:canContinue() then
            currentChoiceIndex = 1
            text = story:continue()
        end
    elseif key == "down" then
        currentChoiceIndex = currentChoiceIndex + 1
        if currentChoiceIndex > choices:getChoiceCount() then
            currentChoiceIndex = 1
        end
    elseif key == "up" then
        currentChoiceIndex = currentChoiceIndex - 1
        if currentChoiceIndex <= 0 then
            currentChoiceIndex = choices:getChoiceCount()
        end
    end
end

--- @param file love.DroppedFile
function love.filedropped(file)
    file:open("r")

    local book = json.decode(file:read())
    story = Nomicon.Story(book)
    choices = Nomicon.ChoiceList(story)
    text = story:canContinue() and story:continue() or ""
end

function love.draw()
    local width, height = love.graphics.getWidth(), love.graphics.getHeight()
    local font = love.graphics.getFont()

    love.graphics.setColor(0.5, 0.5, 0.5, 1.0)
    love.graphics.print("Press UP / DOWN to select a choice.\nPress ENTER to advance.", 16, 16)

    love.graphics.setColor(0.8, 0.8, 0.8, 1.0)
    if not (story and choices) then
        love.graphics.printf("Drag'n'drop an Ink JSON file here!", 32, height / 2, width - 64, "center")
        return
    end
    
    if text and text ~= "" then
        love.graphics.printf(text, width / 2 - DIALOG_WIDTH / 2, height / 2, DIALOG_WIDTH, "justify")
    end

    
    if choices:hasChoices() then
        local _, lines = font:getWrap(text, DIALOG_WIDTH)
        local x = width / 2 - DIALOG_WIDTH / 2
        local y = height / 2 + (#lines + 1) * font:getHeight()

        for i = 1, choices:getChoiceCount() do
            if i == currentChoiceIndex then
                love.graphics.setColor(0, 1, 0, 1)
                love.graphics.print(">", x - 32, y + font:getHeight() / 2, math.sin(love.timer.getTime() / math.pi) * math.rad(22.5), 1, 1, font:getWidth(">"), font:getHeight() / 2)
                love.graphics.setColor(0.8, 0.8, 0.8, 1.0)
            end

            local choice = choices:getChoice(i):getText()
            love.graphics.print(choice, x, y)

            y = y + font:getHeight()
        end
    end
end
