local PATH = (...):gsub("[^%.]+$", "")
local Class = require(PATH .. "Class")
local Utility = require(PATH .. "Utility")
local Value = require(PATH .. "Value")

local TemporaryVariables = Class()

local function __index(self, key)
    local metatable = getmetatable(self)
    return metatable._variables[key] or (metatable._parent and metatable._parent:get(key))
end

local function __newindex(self, key, value)
    local metatable = getmetatable(self)
    local variable = metatable._variables[key]
    do
        local parentVariable = metatable._parent and metatable._parent:get(key)
        if not variable and parentVariable then
            variable = Value(nil, parentVariable)
        end

        if variable then
            variable:assign(value)
        else
            variable = Value(nil, value)
        end
    end

    metatable._variables[key] = variable
end

function TemporaryVariables:new(parent)
    self._parent = parent
    self._variables = {}
    self._proxy = setmetatable({}, {
        _variables = self._variables,
        _parent = parent,
        __index = __index,
        __newindex = __newindex
    })
end

function TemporaryVariables:getParent()
    return self._parent
end

function TemporaryVariables:reset()
    Utility.clearTable(self._variables)
end

function TemporaryVariables:get(key)
    return self._proxy[key]
end

function TemporaryVariables:set(key, value)
    self._proxy[key] = value
end

function TemporaryVariables:iterate()
    return pairs(self._variables)
end

return TemporaryVariables