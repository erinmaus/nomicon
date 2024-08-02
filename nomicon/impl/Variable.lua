local PATH = (...):gsub("[^%.]+$", "")
local Class = require(PATH .. "Class")
local Constants = require(PATH .. "Constants")

local Variable = Class()

local ASSIGN_GLOBAL_VARIABLE    = Constants.ASSIGN_GLOBAL_VARIABLE
local ASSIGN_TEMPORARY_VARIABLE = Constants.ASSIGN_TEMPORARY_VARIABLE
local REFERENCE_VARIABLE        = Constants.REFERENCE_VARIABLE

function Variable:new(object)
    self._object = object

    if object[ASSIGN_GLOBAL_VARIABLE] then
        self._type = ASSIGN_GLOBAL_VARIABLE
        self._name = object[ASSIGN_GLOBAL_VARIABLE]
    elseif object[ASSIGN_TEMPORARY_VARIABLE] then
        self._type = ASSIGN_TEMPORARY_VARIABLE
        self._name = object[ASSIGN_TEMPORARY_VARIABLE]
    elseif object[REFERENCE_VARIABLE] then
        self._type = REFERENCE_VARIABLE
        self._name = object[REFERENCE_VARIABLE]
    end

    self._isCreate = not object[Constants.FIELD_VARIABLE_REASSIGNMENT]
end

function Variable:getType()
    return self._type
end

function Variable:getName()
    return self._name
end

function Variable:getIsGlobal()
    return self._type == ASSIGN_GLOBAL_VARIABLE
end

function Variable:getIsTemporary()
    return self._type == ASSIGN_TEMPORARY_VARIABLE
end

function Variable:getIsReference()
    return self._type == REFERENCE_VARIABLE
end

function Variable:getIsCreate()
    return self._isCreate
end

function Variable:call(executor)
    if self:getIsReference() then
        local value = executor:getTemporaryVariable(self._name) or executor:getGobalVariable(self._name)
        if not value then
            error(string.format("no temporary or global with name '%s' found", value))
        end

        if executor:getIsInExpressionEvaluation() then
            executor:getEvaluationStack():push(value)
        else
            executor:getOutputStack():push(value)
        end
    else
        local value = executor:getEvaluationStack():pop()
        
        if self:getIsGlobal() then
            executor:setGlobalVariable(self._name, value)
        elseif self:getIsTemporary() then
            executor:setTemporaryVariable(self._name, value)
        else
            error(string.format("unhandled variable assignment type '%s'", self._type))
        end
    end
end

function Variable.isVariable(instruction)
    if type(instruction) ~= "table" then
        return false
    end

    local hasValue = instruction[ASSIGN_GLOBAL_VARIABLE] or instruction[ASSIGN_TEMPORARY_VARIABLE] or instruction[REFERENCE_VARIABLE]
    return not not hasValue
end

return Variable