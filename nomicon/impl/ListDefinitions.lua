local PATH = (...):gsub("[^%.]+$", "")
local Class = require(PATH .. "Class")
local ListValue = require(PATH .. "ListValue")
local List = require(PATH .. "List")

--- @class Nomicon.Impl.ListDefinitions
local ListDefinitions = Class()

function ListDefinitions:new(origins)
    self._origins = {}
    self._values = {}

    for listName, origin in pairs(origins) do
        local result = { name = listName, values = {}, valuesByName = {}, valuesByValue = {} }

        for valueName, value in pairs(origin) do
            local v = ListValue(listName, valueName, value)

            result.valuesByName[valueName] = v

            if result.valuesByValue[value] then
                table.insert(result.valuesByValue[value], v)
            else
                result.valuesByValue[value] = { v }
            end
            table.insert(result.values, v)

            if self._values[valueName] then
                table.insert(self._values[valueName], v)
            else
                self._values[valueName] = { v }
            end
        end

        self._origins[listName] = result
    end
end

function ListDefinitions:newListValue(listName, name, value)
    local origin = self._origins[listName]
    if not origin then
        error(string.format("list '%s' not found", listName))
    end

    local listValue = (name and origin.valuesByName[name][1]) or (value and origin.valuesByValue[value])
    if not listValue then
        if name and value then
            error(string.format("list '%s' does not have list value with name '%s' or value %d", listName, name, value))
        elseif name then
            error(string.format("list '%s' does not have list value with name '%s'", listName, name))
        elseif value then
            error(string.format("list '%s' does not have list value with value %d", listName, value))
        end
    else
        if name and listValue:getValueName() ~= name then
            error(string.format("list '%s' has list value with value '%d', but value name is '%s' NOT the expected value name '%s'", listName, value, listValue:getValueName(), name))
        elseif value and listValue:getValue() ~= value then
            error(string.format("list '%s' has list value with name '%s', but value is %d NOT the expected value %d", listName, name, listValue:getValue(), value))
        end
    end

    return 
end

function ListDefinitions:newList(...)
    local values = {}
    for i = 1, select("#", ...) do
        local value = select(i, ...)
        if value and not Class.isDerived(Class.getType(value), ListValue) then
            error(string.format("expected list value, got '%s'", Class.getType(value) and value:getDebugInfo().shortName))
        elseif value and (not self._origins[value:getListName()] or not self._origins[value:getListName()].valuesByName[value:getListName()]) then
            local origin = self._origins[value:getListName()]
            local v = origin and origin.valuesByName[value:getValueName()]

            if not origin then
                error(string.format("list '%s' not found", value:getListName()))
            elseif not v then
                error(string.format("list '%s' does not have value name '%s'", value:getListName(), value:getValueName()))
            elseif v:getValue() ~= value:getValue() then
                error(string.format("value name of '%s' from list '%s' does not have value expected of %d, got %d", value:getValueName(), value:getListName(), value:getValue(), v:getValue()))
            end

            table.insert(values, value)
        end
    end

    return List(self, values)
end

function ListDefinitions:newEmptyList(...)
    local lists = {}

    for i = 1, select("#", ...) do
        local listName = select("#", ...)
        if not lists[listName] then
            local index = #lists + 1

            lists[listName] = index
            lists[index] = listName
        end
    end

    return List(self, {}, lists)
end

function ListDefinitions:newListFromValueNames(...)
    local values = {}

    for i = 1, select("#", ...) do
        local name = select(i, ...)

        local value = self:getValue(name)
        table.insert(values, value)
    end

    return List(self, values)
end

function ListDefinitions:newListFromValues(listName, ...)
    local values = {}

    local origin = self._origins[listName]
    if not origin then
        error(string.format("list '%s' not found", listName))
    end


    for i = 1, select("#", ...) do
        local value = select(i, ...)

        local v
        if type(value) == "number" then
            v = unpack(origin.valuesByValue[value])
            if not v then
                error(string.format("list '%s' does not have a list value of '%d'", value))
            end
        else
            v = self:getValue(listName, value)
        end

        table.insert(values, v)
    end

    return List(self, values)
end

function ListDefinitions:newListFromObject(object)
    local values = {}
    for listValueName, listValue in pairs(object.list) do
        local value = self:tryGetValue(listValueName)
        if not value then
            error(string.format("list value name '%s' not found", listValueName))
        end

        if value:getValue() ~= listValue then
            value = ListValue(value:getListName(), value:getValueName(), listValue)
        end

        table.insert(values, value)
    end

    local lists 
    if object.origins then
        lists = {}
        for _, origin in ipairs(object.origins) do
            table.insert(lists, origin)
            lists[origin] = #lists
        end
    end

    return List(self, values, lists)
end

function ListDefinitions:tryGetListValues(name)
    local i, j = name:find("%.")
    if i and j then
        name = name:sub(1, i - 1)
    end

    return ipairs(self._origins[name].values)
end

function ListDefinitions:hasList(name)
    local i, j = name:find("%.")
    if i and j then
        name = name:sub(1, i - 1)
    end

    return self._origins[name] ~= nil
end

function ListDefinitions:getListValues(name)
    if not self:hasList(name) then
        local i, j = name:find("%.")
        if i and j then
            error(string.format("list '%s' not found", name:sub(1, i - 1)))
        else
            error(string.format("list '%s' not found", name))
        end
    end

    return self:tryGetValue(name)
end

function ListDefinitions:tryGetValue(a, b)
    if a ~= nil then
        if a:find("%.") or b == nil then
            local values = self._values[a] or self._values[a:match("[^.]*%.([^.]*)")]
            if values then
                -- We can't short circuit because it will collapse the unpack into a single value
                -- So no `return values and unpack(values)`...
                return (table.unpack or unpack)(values)
            end

            return nil
        elseif b ~=  nil then
            local origin = self._origins[a]
            if origin then
                if origin.valuesByName[b] then
                    return origin.valuesByName[b]
                elseif origin.valuesByValue[b] then
                    return (table.unpack or unpack)(origin.valuesByValue[b])
                end
            end
        end
    end

    return nil
end

function ListDefinitions:hasValue(a, b)
    return self:tryGetValue(a, b) ~= nil
end

function ListDefinitions:getValue(a, b)
    if a == nil then
        error("parameter 'a' cannot be nil")
    end

    if a:find("%.") then
        if b ~= nil then
            error("parameter 'b' should not be supplied if parameter 'a' is an absolute name")
        end

        local values = self._values[a]
        if not values then
            error(string.format("list value with absolute list value name '%s' not found", a))
        end

        assert(#values == 1, "somehow an absolute name has more than value")
        return values[1]
    end

    if b == nil then
        local values = self._values[a]
        if not values then
            error(string.format("list value(s) with relative list value name '%s' not found", a))
        end

        return (table.unpack or unpack)(values)
    end

    local origin = self._origins[a]
    if not origin then
        error(string.format("list '%s' not found", origin))
    end

    local value = origin.valuesByName[b] or origin.valuesByValue[b]
    if not value then
        error(string.format("list '%s' does not have list value with name or value '%s'", a, tostring(b)))
    end

    return value
end

return ListDefinitions