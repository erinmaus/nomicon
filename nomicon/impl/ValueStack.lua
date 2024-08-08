local PATH = (...):gsub("[^%.]+$", "")
local Class = require(PATH .. "Class")
local Constants = require(PATH .. "Constants")
local Value = require(PATH .. "Value")

local ValueStack = Class()

local GLUE = "\127"

function ValueStack:new(executor, enableTrimming)
    self._stack = {}
    self._top = 0
    self._string = {}
    self._executor = executor
    self._enableTrimming = enableTrimming or false
end

function ValueStack:reset()
    self._top = 0
end

function ValueStack:clean()
    while #self._stack > self._top do
        table.remove(self._stack, #self._stack)
    end

    while #self._string > self._top do
        table.remove(self._string, #self._string)
    end
end

function ValueStack:copy(other)
    other = other or ValueStack()

    for i = 1, self._top do
        local selfValue = self._stack[i]
        other._executor = self._executor
        other._stack[i] = selfValue:copy(other._stack[i])
        other._string[i] = self._string[i]
        other._enableTrimming = self._enableTrimming
    end
    other._top = self._top

    return other
end

function ValueStack:getCount()
    return self._top
end

function ValueStack:_toAbsoluteIndex(index)
    index = index or -1
    if index < 0 then
        index = self._top + index + 1
    end
    return index
end

function ValueStack:set(index, value)
    index = self:_toAbsoluteIndex(index)
    if not (index >= 1 and index <= self._top) then
        error(string.format("cannot set value at index (%d): out of bounds", index))
    end

    self._stack[self._top]:copyFrom(value)
    self._string[self._top] = self._stack[self._top]:cast(Constants.TYPE_STRING) or ""
end

function ValueStack:peek(index)
    index = self:_toAbsoluteIndex(index)
    if index >= 1 and index <= self._top then
        return self._stack[index]
    end

    return nil
end

function ValueStack:isWhitespace(startIndex, stopIndex)
    if not (startIndex and stopIndex) then
        startIndex = 1
        stopIndex = self._top
    else
        startIndex = self:_toAbsoluteIndex(startIndex or 1)
        stopIndex = self:_toAbsoluteIndex(stopIndex or startIndex)
    end

    if stopIndex < startIndex then
        error("cannot convert to reversed string (stopIndex < startIndex)")
    end

    if not (startIndex >= 1 and startIndex <= self._top) then
        error(string.format("startIndex (%d) out of bounds", startIndex))
    end

    if not (stopIndex >= 1 and stopIndex <= self._top) then
        error(string.format("stopIndex (%d) out of bounds", stopIndex))
    end

    for i = startIndex, stopIndex do
        local text = self._string[i]
        local value = self._stack[i]
        if not text:match("^([%s\n\r\127]*)$") and not value:is(Constants.TYPE_TAG) then
            return false
        end
    end

    return true
end

function ValueStack:toString(startIndex, stopIndex)
    if not (startIndex and stopIndex) then
        startIndex = 1
        stopIndex = self._top
    else
        startIndex = self:_toAbsoluteIndex(startIndex or 1)
        stopIndex = self:_toAbsoluteIndex(stopIndex or startIndex)
    end

    if stopIndex < startIndex then
        error("cannot convert to reversed string (stopIndex < startIndex)")
    end

    if not (startIndex >= 1 and startIndex <= self._top) then
        error(string.format("startIndex (%d) out of bounds", startIndex))
    end
    
    if not (stopIndex >= 1 and stopIndex <= self._top) then
        error(string.format("stopIndex (%d) out of bounds", stopIndex))
    end

    local hasGlue = false
    for i = startIndex, stopIndex do
        if self._string[i] == GLUE then
            hasGlue = true
            break
        end
    end

    local result = table.concat(self._string, "", startIndex, stopIndex)
    if hasGlue then
        result = result:gsub("([\n\r]*\127[\n\r]*)", "")
    end

    return result
end

function ValueStack:unpack(startIndex, stopIndex)
    startIndex = self:_toAbsoluteIndex(startIndex)
    stopIndex = self:_toAbsoluteIndex(stopIndex)

    if stopIndex < startIndex then
        error("cannot convert to reversed string (stopIndex < startIndex)")
    end

    if not (startIndex >= 1 and startIndex <= self._top) then
        error(string.format("startIndex (%d) out of bounds", startIndex))
    end

    if not (stopIndex >= 1 and stopIndex <= self._top) then
        error(string.format("stopIndex (%d) out of bounds", stopIndex))
    end

    return (table.unpack or unpack)(startIndex, stopIndex)
end

function ValueStack:clear()
    self._top = 0
end

function ValueStack:_pop(start, stop, top)
    local value
    if stop > top then
        value = Value.VOID
    else
        value = self._stack[start]
    end

    if start == stop then
        return value
    else
        return value, self:_pop(start + 1, stop, top)
    end
end

function ValueStack:pop(count)
    count = count or 1

    if count <= 0 then
        error("cannot pop zero or less values")
    end

    local startIndex = self:_toAbsoluteIndex(-count)
    local stopIndex = self:_toAbsoluteIndex(-1)

    local top = self._top
    self._top = self._top - count

    return self:_pop(startIndex, stopIndex, top)
end

function ValueStack:remove(index)
    index = self:_toAbsoluteIndex(index)
    if not (index >= 1 and index <= self._top) then
        error(string.format("index (%d) out of bounds", index))
    end
    
    local value = table.remove(self._stack, index)
    table.insert(self._stack, value)
    
    -- Keep the string value around for debugging purposes.
    -- It'll just get replaced when self._top increments.
    local stringValue = table.remove(self._string, index)
    table.insert(self._string, stringValue)
    
    self._top = self._top - 1

    return value, stringValue
end

function ValueStack:_getFunctionStartPointer()
    local callStack = self._executor:getCurrentFlow():getCurrentThread():getCallStack()
    if callStack:getFrameCount() >= 1 and callStack:getFrame():getType() == Constants.DIVERT_TO_FUNCTION then
        return callStack:getFrame():getOutputStackPointer()
    end

    return nil
end

function ValueStack:_getGluePointer()
    for i = self:getCount(), 1, -1 do
        if self:peek(i):is(Constants.TYPE_GLUE) then
            return i
        end
    end

    return nil
end

function ValueStack:_getTrimIndex()
    local functionStartPointer = self:_getFunctionStartPointer()
    local gluePointer = self:_getGluePointer()

    if gluePointer and functionStartPointer then
        return math.min(functionStartPointer, gluePointer)
    end

    return functionStartPointer or gluePointer
end

function ValueStack:_trimWhitespace()
    local stringEvaluationPointer = self._executor:getCurrentFlow():getCurrentStringEvaluationPointer()
    for i = self:getCount(), stringEvaluationPointer + 1, -1 do
        if self:isWhitespace(i, i) and not self:peek(i):is(Constants.TYPE_TAG) then
            self:remove(i)
        end
    end
end

function ValueStack:_valueBefore(index)
    index = self:_toAbsoluteIndex(index)
    for i = index, 1, -1 do
        local value = self:peek(i)
        if not value:is(Constants.TYPE_TAG) then
            return i, i
        end
    end

    return 1, 1
end

function ValueStack:_pushString(value)
    if Class.isDerived(Class.getType(value), Value) then
        if value:is(Constants.TYPE_GLUE) then
            self:_trimWhitespace()
            return self:_push(value)
        end

        value = value:cast(Constants.TYPE_STRING)
    end

    if (self:getCount() == 0 or self:toString(self:_valueBefore(-1)):find("\n$")) and value:match("^[%s\n\r]+$") then
        return Value.VOID
    end
    
    local stringEvaluationPointer = self._executor:getCurrentFlow():getCurrentStringEvaluationPointer()
    if stringEvaluationPointer >= 1 then
        return self:_push(value)
    end

    local trimIndex = self:_getTrimIndex()
    if not trimIndex or trimIndex <= stringEvaluationPointer then
        return self:_push(value)
    end

    if self:getCount() >= 1 and self:toString(self:_valueBefore(-1)):find("[%s\n\r]$") and value:match("^[%s\n\r]+$") then
        return Value.VOID
    end
    
    return self:_push(value)
end

function ValueStack:_push(value)
    self._top = self._top + 1

    local selfValue = self._stack[self._top]
    if not selfValue then
        selfValue = Value(nil, value)
        self._stack[self._top] = selfValue
    else
        selfValue:copyFrom(value)
    end

    local value = (selfValue:is(Constants.TYPE_TAG) and "") or selfValue:cast(Constants.TYPE_STRING) or ""
    assert(type(value) == "string", "cast to string but did not get string back")

    if selfValue:getType() ~= Constants.TYPE_GLUE then
        if value:find(GLUE) then
            value = value:gsub(GLUE, "")
        end
    end

    self._string[self._top] = value

    return selfValue
end

function ValueStack:push(value)
    if self._enableTrimming then
        local isValueString = Class.isDerived(Class.getType(value), Value)
        isValueString = isValueString and (value:is(Constants.TYPE_GLUE) or value:is(Constants.TYPE_STRING))
        isValueString = isValueString or type(value) == "string"

        if isValueString then
            return self:_pushString(value)
        end
    end

    return self:_push(value)
end

return ValueStack
