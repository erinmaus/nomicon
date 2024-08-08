local PATH = (...):gsub("[^%.]+$", "")
local Class = require(PATH .. "impl.lass")
local ImplChoice = require(PATH .. "impl.hoice")

--- @class Nomicon.Choice represents a wrapper around a choice
--- @overload fun(choice: Nomicon.Impl.Choice, index: integer, story: Nomicon.Story): Nomicon.Choice
local Choice = Class()

--- Internal. Constructs a new Choice.
---
--- @param choice Nomicon.Impl.Choice the choice to wrap
--- @param index integer the index into the ChoiceList this choice belongs to (not to be confused with the index into the story's choice list - that's different!)
--- @param story Nomicon.Story the story the choice belongs to
function Choice:new(choice, index, story)
    self._choice = choice
    self._index = index
    self._story = story
end

--- Returns the index of the choice into the choice list this choice came from.
--- 
--- Not to be confused with the index into the Story (or internally the Executor's) choice list.
--- These are two different indices!
--- 
--- @return integer
function Choice:getIndex()
    return self._index
end

--- Gets the text of the choice.
--- 
--- @return string
function Choice:getText()
    return self._choice:getText()
end

--- Chooses the choice. 
--- 
--- @return boolean success returns true if the choice could be chosen, false otherwise
function Choice:choose()
    return self._story:choose(self._choice)
end

--- Returns the number of tags attached to this choice.
--- 
--- @return integer number
function Choice:getTagCount()
    return self._choice:getTagCount()
end

--- Gets a tag at the specific index.
--- @param index integer index into the tag list; a value less than zero will wrap to the beginning (so -1 will return the last tag)
--- @return string | nil
function Choice:getTag(index)
    return self._choice:getTag(index)
end

return Choice
