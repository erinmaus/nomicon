local PATH = (...):gsub("[^%.]+$", "")
local Class = require(PATH .. "Class")
local Constants = require(PATH .. "Constants")

local Variable = Class()

local ASSIGN_GLOBAL_VARIABLE    = Constants.ASSIGN_GLOBAL_VARIABLE
local ASSIGN_TEMPORARY_VARIABLE = Constants.ASSIGN_TEMPORARY_VARIABLE
local REFERENCE_VARIABLE        = Constants.REFERENCE_VARIABLE
local READ_COUNT                = Constants.READ_COUNT

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
    elseif object[READ_COUNT] then
        self._type = READ_COUNT
        self._name = object[READ_COUNT]
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

function Variable:getIsReadyCount()
    return self._type == READ_COUNT
end

function Variable:getIsCreate()
    return self._isCreate
end

function Variable:call(executor)
    if self:getIsReference()  or self:getIsReadyCount() then
        local value
        if self:getIsReference() then
            value = executor:getTemporaryVariable(self._name) or executor:getGlobalVariable(self._name)
            if not value then
                error(string.format("no temporary or global with name '%s' found", self._name))
            end

            while value and value:is(Constants.TYPE_POINTER) do
                local pointer = value:getValue()
                if pointer:getContextIndex() <= 0 then
                    value = executor:getGlobalVariable(pointer:getVariable())
                end

                if not value and pointer:getContextIndex() ~= 0 then
                    value = executor:getTemporaryVariable(pointer:getVariable(), pointer:getContextIndex())
                end
            end
        elseif self:getIsReadyCount() then
            value = executor:getVisitCountForContainer(executor:getContainer(self._name))
        end

        if executor:getIsInExpressionEvaluation() then
            executor:getEvaluationStack():push(value)
        else
            executor:getOutputStack():push(value)
        end
    else
        local value = executor:getEvaluationStack():pop()

        local name, contextIndex, currentValue
        if self:getIsGlobal() then
            currentValue = executor:getGlobalVariable(self._name)
            contextIndex = 0
        elseif self:getIsTemporary() then
            currentValue = executor:getTemporaryVariable(self._name)
            contextIndex = -1
        else
            error(string.format("unhandled variable assignment type '%s'", self._type))
        end

        if currentValue and currentValue:is(Constants.TYPE_POINTER) then
            local currentPointer = currentValue:getValue()
            while currentPointer do
                local otherValue
                if currentPointer:getContextIndex() == 0 then
                    otherValue = executor:getGlobalVariable(currentPointer:getVariable())
                    contextIndex = otherValue and 0 or contextIndex
                end

                if not otherValue and currentPointer:getContextIndex() ~= 0 then
                    otherValue = executor:getTemporaryVariable(currentPointer:getVariable(), currentPointer:getContextIndex())
                    contextIndex = otherValue and currentPointer:getContextIndex() or contextIndex
                end

                if otherValue and otherValue:is(Constants.TYPE_POINTER) then
                    currentPointer = otherValue:getValue()
                else
                    name = currentPointer:getVariable()
                    break
                end
            end
        else
            name = self._name
        end
        
        if contextIndex == 0 then
            executor:setGlobalVariable(name, value)
        else
            executor:setTemporaryVariable(name, value, contextIndex)
        end
    end
end

function Variable.isVariable(instruction)
    if type(instruction) ~= "table" then
        return false
    end

    local hasValue = instruction[ASSIGN_GLOBAL_VARIABLE] or instruction[ASSIGN_TEMPORARY_VARIABLE] or instruction[REFERENCE_VARIABLE] or instruction[READ_COUNT]
    return not not hasValue
end

return Variable
