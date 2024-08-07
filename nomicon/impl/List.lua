local PATH = (...):gsub("[^%.]+$", "")
local Class = require(PATH .. "Class")
local Constants = require(PATH .. "Constants")
local ListValue = require(PATH .. "ListValue")

--- @class Nomicon.Impl.List represents an Ink list (in other places this would be called a set)
--- @field _values Nomicon.Impl.ListValue[]
--- @overload fun(definitions: Nomicon.Impl.ListDefinitions, values: Nomicon.Impl.ListValue[], lists?: table): Nomicon.Impl.List
local List = Class()

--- Internal. Constructs a list.
--- 
--- This should be done via ListDefinitions.
--- 
--- @param definitions Nomicon.Impl.ListDefinitions the list definitions from the story
--- @param values Nomicon.Impl.ListValue[] the array of values that this list has
--- @param lists table (internal) a cached list of lists this set belongs to
---
--- @see Nomicon.Impl.ListDefinitions
function List:new(definitions, values, lists)
    self._definitions = definitions
    self._values = {}
    for i, value in ipairs(values) do
        table.insert(self._values, ListValue.from(value, i))
    end
    ListValue.sort(self._values)

    if not lists then
        self._lists = {}
        for _, value in ipairs(self._values) do
            local name = value:getListName()

            if not self._lists[name] then
                local index = #self._lists + 1

                self._lists[name] = index
                self._lists[index] = name
            end
        end
    else
        self._lists = lists
    end

    local s = {}
    for _, value in self:values() do
        table.insert(s, value:getValueName())
    end
    self._string = table.concat(s, ", ")
end

--- Returns true if this list is empty, false otherwise.
--- @return boolean
function List:empty()
    return #self._values == 0
end

--- Increments this list by an integer.
--- 
--- All list values will be incremented by 'value' and converted into the correct ListValue.
--- If a list value, when incremented by 'value', does not produce a valid value, then
--- it will not be present in the new list.
--- 
--- @param value integer
--- @return Nomicon.Impl.List
function List:increment(value)
    local values = {}
    for _, listValue in ipairs(self._values) do
        local newListValue = listValue:getValue() + value
        local nextValue = self._definitions:tryGetValue(listValue:getListName(), newListValue)
        if nextValue then
            table.insert(values, nextValue)
        end
    end

    return List(self._definitions, values, self._lists)
end

--- Decrements this list by a value.
--- 
--- @param value integer
function List:decrement(value)
    return self:increment(-value)
end

--- Returns the sorted list as a string.
--- 
--- The list: (pizza.onion, pizza.pepper, spaghetti.onion) would thus print as:
--- 
--- `onion, pepper, onion`
--- @return string
function List:toString()
    return self._string
end

--- Returns the minimum list value of this list.
--- @return Nomicon.Impl.ListValue | nil
function List:getMinValue()
    return self._values[1]
end

--- Returns the maximum list value of this list.
--- @return Nomicon.Impl.ListValue | nil
function List:getMaxValue()
    return self._values[#self._values]
end

--- Returns an ordered iterator over the list values.
--- @return fun(table: Nomicon.Impl.ListValue[], i?: integer):(integer,Nomicon.Impl.ListValue), Nomicon.Impl.ListValue[], integer
function List:values()
    return ipairs(self._values)
end

--- Gets a value by index.
--- @param index integer index into the list; can be negative to wrap around to the last item
--- @return Nomicon.Impl.ListValue | nil listValue the list value at the index or nil if index is out of bounds
function List:getValueByIndex(index)
    if index < 0 then
        index = index + #self._values + 1
    end

    return self._values[index]
end

--- Returns the number of list item values in the list
--- @return integer
function List:getCount()
    return #self._values
end

function List:assign(otherList)
    local lists = {}
    for index, listName in ipairs(self._lists) do
        lists[index] = listName
        lists[listName] = index
    end

    for _, listName in ipairs(otherList._lists) do
        if not lists[listName] then
            table.insert(lists, listName)
            lists[listName] = #lists
        end
    end

    return List(self._definitions, otherList._values, lists)
end

--- Combines two lists. Returns a third list which is the union of this list and otherList.
--- @param otherList Nomicon.Impl.List the list to combine with
--- @return Nomicon.Impl.List list union of this list and the other list
function List:add(otherList)
    local values = {}

    for _, value in pairs(otherList._values) do
        table.insert(values, value)
    end

    for _, value in ipairs(self._values) do
        if not otherList:hasValue(value) then
            table.insert(values, value)
        end
    end

    return List(self._definitions, values)
end

--- Removes the items in the other list from this list.
--- 
--- @param otherList Nomicon.Impl.List the list of values to remove
--- @return Nomicon.Impl.List list the new list with the removed values
function List:remove(otherList)
    local values = {}
    for _, value in pairs(self._values) do
        if not otherList:hasValue(value) then
            table.insert(values, value)
        end
    end

    return List(self._definitions, values, self._lists)
end

--- Returns true if the list has the provided value, false otherwise.
--- @param value Nomicon.Impl.ListValue
--- @return boolean
function List:hasValue(value)
    if type(value) == "number" then
        for _, v in ipairs(self._values) do
            if v:getValue() == value then
                return true
            end
        end
    elseif type(value) == "string" then
        for _, v in ipairs(self._values) do
            if v:getName() == value then
                return true
            end
        end
    elseif Class.isDerived(Class.getType(value), ListValue) then
        for _, v in ipairs(self._values) do
            if v:getName() == value:getName() then
                return true
            end
        end
    end

    return false
end

--- Returns true if this list contains the other list.
--- @param other Nomicon.Impl.List the other list to compare against
--- @return boolean
function List:contains(other)
    if self:empty() or other:empty() then
        return false
    end

    for _, value in other:values() do
        if not self:hasValue(value) then
            return false
        end
    end

    return true
end

--- Returns the intersection of this list and the other list.
--- @param other Nomicon.Impl.List the other list to intersect against
--- @return Nomicon.Impl.List
function List:intersect(other)
    local values = {}

    for _, value in self:values() do
        if other:hasValue(value) then
            table.insert(values, value)
        end
    end

    return List(self._definitions, values)
end

--- Returns a list that contains *all* the possible values.
--- @return Nomicon.Impl.List
function List:all()
    local values = {}

    for _, listName in ipairs(self._lists) do
        for _, value in self._definitions:tryGetListValues(listName) do
            table.insert(values, value)
        end
    end

    return List(self._definitions, values, self._lists)
end

--- Returns the inversion of this list.
--- 
--- Any possible value this lsit has, the returned list will not and any possible value this list does not have, the returned list will.
--- 
--- @return Nomicon.Impl.List
function List:invert()
    local values = {}

    for _, listName in ipairs(self._lists) do
        for _, value in self._definitions:tryGetListValues(listName) do
            if not self:hasValue(value) then
                table.insert(values, value)
            end
        end
    end

    return List(self._definitions, values, self._lists)
end

--- Returns the list values between min and max inclusive that are present in this list.
--- 
--- If min is a list, its min value will be used.
--- 
--- @param min Nomicon.Impl.List | Nomicon.Impl.ListValue | number the minimum list, list value, or list value as a number
--- @param max Nomicon.Impl.List | Nomicon.Impl.ListValue | number the maximum list, list value, or list value as a number
--- @return Nomicon.Impl.List
function List:range(min, max)
    if self:getCount() == 0 then
        return List(self._definitions, {}, self._values)
    end

    local minType = Class.getType(min)
    if Class.isDerived(minType, List) then
        min = min:getMinValue():getValue()
    elseif Class.isDerived(minType, ListValue) then
        min = minType:getValue()
    elseif type(min) ~= "number" then
        error("'min' must be List, ListValue, or number")
    end

    local maxType = Class.getType(max)
    if Class.isDerived(maxType, List) then
        max = max:getMaxValue():getValue()
    elseif Class.isDerived(maxType, ListValue) then
        max = maxType:getValue()
    elseif type(max) ~= "number" then
        error("'min' must be List, ListValue, or number")
    end

    local values = {}
    for _, value in self:values() do
        if value:getValue() >= min and value:getValue() <= max then
            table.insert(values, value)
        end
    end

    return List(self._definitions, values, self._lists)
end

--- Returns true if this list has every value in the other list and vice versa, false otherwise.
--- @param other Nomicon.Impl.List the list to compare against
--- @return boolean
function List:equal(other)
    if self:getCount() ~= other:getCount() then
        return false
    end

    for _, value in self:values() do
        if not other:hasValue(value) then
            return false
        end
    end

    return true
end

--- Returns true if this list is less than the other.
--- 
--- That is, this list's minimum value is less than the other list's maximum value.
--- 
--- @param other Nomicon.Impl.List
--- @return boolean
function List:less(other)
    local selfMinValue = self:getMinValue()
    selfMinValue = selfMinValue and selfMinValue:getValue() or 0

    local otherMaxValue = other:getMaxValue()
    otherMaxValue = otherMaxValue and otherMaxValue:getValue() or 0
    
    return selfMinValue < otherMaxValue
end

--- Returns true if this list is less than or equal to the other
--- 
--- A list is less than or equal to another if the count of items is the same in both lists and
--- the left-side (self) list's minimum value is less than the right-side (other) list's maximum value.
--- @param other Nomicon.Impl.List
--- @return boolean
function List:lessThanOrEquals(other)
    local selfMinValue = self:getMinValue()
    selfMinValue = selfMinValue and selfMinValue:getValue() or 0

    local otherMaxValue = other:getMaxValue()
    otherMaxValue = otherMaxValue and otherMaxValue:getValue() or 0

    return self:getCount() == other:getCount() and selfMinValue <= otherMaxValue
end

--- Returns true if this list is greater than the other.
--- 
--- That is, this list's maximum value is greater than the other list's minimum value.
function List:greater(other)
    local selfMinValue = self:getMinValue()
    selfMinValue = selfMinValue and selfMinValue:getValue() or 0

    local otherMaxValue = other:getMaxValue()
    otherMaxValue = otherMaxValue and otherMaxValue:getValue() or 0

    return selfMinValue > otherMaxValue
end

--- Returns true if this list is greater than or equal to the other.
---
--- A list is greater than or equal to another if the count of items is the same in both lists and
--- the left-side (self) list's maximum value is greater than the right-side (other) list's minimum value.
--- @param other Nomicon.Impl.List
--- @return boolean
function List:greaterThanOrEquals(other)
    local selfMinValue = self:getMinValue()
    selfMinValue = selfMinValue and selfMinValue:getValue() or 0

    local otherMaxValue = other:getMaxValue()
    otherMaxValue = otherMaxValue and otherMaxValue:getValue() or 0

    return self:getCount() == other:getCount() and selfMinValue >= otherMaxValue
end

--- Pushes this list to the output or evaluation stacks depending on the expression evaluation mode.
--- 
--- @param executor  Nomicon.Impl.Executor
function List:call(executor)
    if executor:getIsInExpressionEvaluation() then
        executor:getEvaluationStack():push(self)
    else
        executor:getOutputStack():push(self)
    end
end

--- Returns true if the instruction (object) is a list.
--- @return boolean
function List.isList(instruction)
    if type(instruction) ~= "table" then
        return false
    end

    return type(instruction[Constants.VALUE_FIELD_LIST]) == "table"
end

return List
