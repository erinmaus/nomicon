local PATH = (...):gsub("[^%.]+$", "")
local Class = require(PATH .. "Class")

--- @class Nomicon.Impl.ListValue
--- @overload fun(listName: string, valueName: string, value: number, index: number?): Nomicon.Impl.ListValue
local ListValue = Class()

--- Internal. Constructs a ListValue.
--- 
--- This should be done via ListDefinitions.
--- 
--- @param listName string name of the list in the list definitions
--- @param valueName string name of the value in the list
--- @param value number the number value of the list value
--- @param index integer? (internal) the index of the list value in the list
--- 
--- @see Nomicon.Impl.ListDefinitions
function ListValue:new(listName, valueName, value, index)
    self._name = string.format("%s.%s", listName, valueName)
    self._listName = listName
    self._valueName = valueName
    self._value = value
    self._index = index or 0
end

--- Gets the full `list.value` name of this value
--- @return string name name of the list
function ListValue:getName()
    return self._name
end

--- Gets the name of the value in the list this value belongs to
--- @return string valueName name of the value in the list
function ListValue:getValueName()
    return self._valueName
end

--- Gets the name of the list this value belongs to
--- @return string listName name of the list
function ListValue:getListName()
    return self._listName
end

--- Gets the number-based value of this list value
--- @return number value value of the list value object
function ListValue:getValue()
    return self._value
end

--- Internal. Gets the original index of the list value in the list.
--- @return integer
function ListValue:getIndex()
    return self._index
end

--- Internal. Sets the original index of the list value in the list.
--- @param value integer
function ListValue:setIndex(value)
    self._index = value
end

--- Internal. Creates a list from another list.
--- @param other Nomicon.Impl.ListValue
--- @param index integer
function ListValue.from(other, index)
    return ListValue(other._listName, other._valueName, other._value, index or other._index)
end

local function sortValueFunc(a, b)
    if a:getValue() == b:getValue() then
        return a:getIndex() < b:getIndex()
    end

    return a:getValue() < b:getValue()
end

function ListValue.sort(values)
    table.sort(values, sortValueFunc)
end

return ListValue
