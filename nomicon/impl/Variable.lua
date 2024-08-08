local PATH = (...):gsub("[^%.]+$", "")
local Class = require(PATH .. "Class")
local Constants = require(PATH .. "Constants")
local Pointer = require(PATH .. "Pointer")
local Value = require(PATH .. "Value")
local List = require(PATH .. "List")

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

function Variable:getIsReadCount()
    return self._type == READ_COUNT
end

function Variable:getIsCreate()
    return self._isCreate
end

function Variable:call(executor)
    if self:getIsReference() or self:getIsReadCount() then
        local value
        if self:getIsReference() then
            value = executor:getTemporaryVariable(self._name) or executor:getGlobalVariable(self._name)
            if not value then
                value = executor:getListDefinitions():tryGetValue(self._name)
                if value then
                    value = Value(nil, executor:getListDefinitions():newList(value))
                end
            end

            if not value then
                error(string.format("no temporary, global, or list value with name '%s' found", self._name))
            end

            while value and value:is(Constants.TYPE_POINTER) do
                local pointer = value:getValue()
                -- if pointer:getContextIndex() <= 0 then
                --     value = executor:getGlobalVariable(pointer:getVariable())
                -- end

                -- if not value and pointer:getContextIndex() ~= 0 then
                --     value = executor:getTemporaryVariable(pointer:getVariable(), pointer:getContextIndex())
                -- end
                local globalValue
                if pointer:getContextIndex() <= 0 then
                    globalValue = executor:getGlobalVariable(pointer:getVariable())
                end

                local temporaryValue
                if not globalValue and pointer:getContextIndex() ~= 0 then
                    temporaryValue = executor:getTemporaryVariable(pointer:getVariable(), pointer:getContextIndex())
                end

                value = temporaryValue or globalValue
            end
        elseif self:getIsReadCount() then
            value = executor:getVisitCountForContainer(executor:getContainer(self._name))
        end

        if executor:getIsInExpressionEvaluation() then
            executor:getEvaluationStack():push(value)
        else
            executor:getOutputStack():push(value)
        end
    else
        local value = executor:getEvaluationStack():pop()

        local name, contextIndex
        if self._isCreate then
            if value:is(Constants.TYPE_POINTER) then
                name = self._name
                contextIndex = -1

                local currentPointer = value:getValue()
                if currentPointer:getContextIndex() < 0 then
                    local referenceValue = executor:getTemporaryVariable(currentPointer:getVariable())
                    local updatedContextIndex
                    if referenceValue then
                        updatedContextIndex = executor:getTemporaryVariableContextIndex(currentPointer:getVariable())
                    else
                        referenceValue = executor:getGlobalVariable(currentPointer:getVariable())
                        if referenceValue then
                            updatedContextIndex = 0
                        else
                            error(string.format("reference to variable '%s' not found", currentPointer:getVariable()))
                        end
                    end

                    if referenceValue:is(Constants.TYPE_POINTER) then
                        value = referenceValue:getValue()
                    else
                        value = currentPointer:updateContextIndex(updatedContextIndex, Pointer(currentPointer:getObject()))
                    end
                end
            end
        else
            local temporaryVariable = executor:getTemporaryVariable(self._name)
            local globalVariable = executor:getTemporaryVariable(self._name)
            local currentValue = temporaryVariable or globalVariable

            if currentValue and currentValue:is(Constants.TYPE_POINTER) then
                local currentPointer = currentValue:getValue()
                while currentPointer do
                    name = currentPointer:getVariable()
                    contextIndex = currentPointer:getContextIndex()

                    local nextPointer
                    if contextIndex == 0 then
                        nextPointer = executor:getGlobalVariable(name)
                    elseif contextIndex >= 1 then
                        nextPointer = executor:getTemporaryVariable(name, contextIndex)
                    else
                        error(string.format("re-assigned pointer to variable '%s' has invalid context index", name))
                    end

                    currentPointer = nextPointer:cast(Constants.TYPE_POINTER)
                end
            end

            if not (name and contextIndex) then
                if temporaryVariable then
                    name = self._name
                    contextIndex = -1
                elseif globalVariable then
                    name = self._name
                    contextIndex = 0
                end
            end
        end

        if not (name and contextIndex) then
            name = self._name
            if self:getIsGlobal() then
                contextIndex = 0
            elseif self:getIsTemporary() then
                contextIndex = -1
            else
                error(string.format("unhandled variable assignment type '%s'", self._type))
            end
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
