local PATH = (...):gsub("[^%.]+$", "")
local Class = require(PATH .. "Impl.Class")
local Choice = require(PATH .. "Choice")

--- @class Nomicon.ChoiceList represents a list of visible choices
--- @overload fun(story: Nomicon.Story): Nomicon.ChoiceList
local ChoiceList = Class()

--- Constructs a new ChoiceList.
--- 
--- @param story Nomicon.Story the story to wrap the choice list for
function ChoiceList:new(story)
    self._story = story
end

--- Returns true if this choice list has choices (choice count >= 1), false otherwise.
--- @return boolean
function ChoiceList:hasChoices()
    return self:getChoiceCount() >= 1
end

--- Returns the number of visible and selectable choices available.
--- @return integer
function ChoiceList:getChoiceCount()
    local count = 0
    for i = 1, self._story:getChoiceCount() do
        if self._story:getChoice(i):getIsSelectable() and not self._story:getChoice(i):getChoicePoint():getIsInvisibleDefault() then
            count = count + 1
        end
    end

    return count
end

--- Gets a choice at the specific index.
--- @param index integer the index of the choice; values less than 0 wrap around so -1 will be the last choice
--- @return Nomicon.Choice | nil
function ChoiceList:getChoice(index)
    if index < 0 then
        index = self:getChoiceCount() + index + 1
    end

    local count = 0
    for i = 1, self._story:getChoiceCount() do
        if self._story:getChoice(i):getIsSelectable() and not self._story:getChoice(i):getChoicePoint():getIsInvisibleDefault() then
            count = count + 1
        end

        if count == index then
            return Choice(self._story:getChoice(i))
        end
    end

    return nil
end

return ChoiceList
