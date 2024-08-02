local PATH = (...):gsub("[^%.]+$", "")
local Class = require(PATH .. "Class")
local TemporaryVariables = require(PATH .. "TemporaryVariables")

local CallStackFrame = Class()

function CallStackFrame:new(callStack)
    self._callStack = callStack
    self._logicalEvaluationDepth = 0

    if callStack:hasFrames() then
        self._temporaryVariables = TemporaryVariables(callStack:getFrame()._temporaryVariables)
    else
        self._temporaryVariables = TemporaryVariables()
    end
end

function CallStackFrame:getIsInExpressionEvaluation()
    return self._logicalEvaluationDepth >= 1
end

function CallStackFrame:enterLogicalEvaluation()
    self._logicalEvaluationDepth = self._logicalEvaluationDepth + 1
end

function CallStackFrame:leaveLogicalEvaluation()
    if self._logicalEvaluationDepth < 1 then
        error("cannot leave logical evaluation mode; stack unbalanced!")
    end

    self._logicalEvaluationDepth = self._logicalEvaluationDepth - 1
end

function CallStackFrame:reset()
    self._temporaryVariables:reset()

    self._type = nil
    self._container = nil
    self._index = nil
end

function CallStackFrame:getCallStack()
    return self._callStack
end

function CallStackFrame:getTemporaryVariables()
    return self._temporaryVariables
end

function CallStackFrame:getPointer()
    return self._container, self._index
end

function CallStackFrame:getType()
    return self._type
end

function CallStackFrame:enter(divertType, container, index)
    self._type = divertType
    self._container = container
    self._index = index
end

function CallStackFrame:jump(container, index)
    self._container = container
    self._index = index or (container and 1 or nil)
end

function CallStackFrame:canLeave(divertType)
    if divertType == nil then
        return true
    end

    if divertType ~= self._type then
        return false
    end

    return true
end

function CallStackFrame:leave(divertType)
    if not self:canLeave(divertType) then
        error(string.format("expected to leave via '%s', instead got '%s'", self._type, divertType))
    end

    self:reset()
end

function CallStackFrame:copy(other)
    other = other or CallStackFrame(self._callStack)

    other._logicalEvaluationDepth = self._logicalEvaluationDepth
    other._type = self._type
    other._container = self._container
    other._index = self._index

    other._temporaryVariables:reset()
    for name, value in self._temporaryVariables:iterate() do
        other._temporaryVariables:set(name, value)
    end

    return other
end

return CallStackFrame
