local PATH = (...):gsub("[^%.]+$", "")
local Class = require(PATH .. "Class")

--- @class Nomicon.Impl.ListValue
--- @overload fun(listName: string, valueName: string, value: number): Nomicon.Impl.ListValue
local ListValue = Class()

--- Internal. Constructs a ListValue.
--- 
--- This should be done via ListDefinitions.
--- 
--- @param listName string name of the list in the list definitions
--- @param valueName string name of the value in the list
--- @param value number the number value of the list value
--- 
--- @see Nomicon.Impl.ListDefinitions
function ListValue:new(listName, valueName, value)
    self._name = string.format("%s.%s", listName, valueName)
    self._listName = listName
    self._valueName = valueName
    self._value = value
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

return ListValue
