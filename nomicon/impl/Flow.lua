local PATH = (...):gsub("[^%.]+$", "")
local Choice = require(PATH .. "Choice")
local Class = require(PATH .. "Class")
local Constants = require(PATH .. "Constants")
local Thread = require(PATH .. "Thread")
local Utility = require(PATH .. "Utility")
local Value = require(PATH .. "Value")
local ValueStack = require(PATH .. "ValueStack")

local Flow = Class()

function Flow:new(executor, name)
    self._name = name
    self._executor = executor
    self._evaluationStack = ValueStack(executor)
    self._outputStack = ValueStack(executor, true)
    self._tagStack = ValueStack(executor)

    self._logicalEvaluationDepth = 0
    self._outputStackStringPointers = {}
    self._outputStackTagIndices = {}

    self._choiceTags = {}
    self._choices = {}
    self._choiceCount = 0

    self._tags = {}
    self._previousTagCount = 0

    self._nextTags = {}
    self._currentText = ""

    self._threads = { Thread(executor) }
    self._top = 1
end

function Flow:getName()
    return self._name
end

function Flow:getTagCount()
    return #self._tags
end

function Flow:getTag(index)
    return self._tags[index]
end

function Flow:getText()
    return self._currentText
end

function Flow:getEvaluationStack()
    return self._evaluationStack
end

function Flow:getOutputStack()
    return self._outputStack
end

function Flow:getIsInExpressionEvaluation()
    local frame = self:getCurrentThread():getCallStack():getFrame()
    return frame and frame:getIsInExpressionEvaluation()
end

function Flow:enterLogicalEvaluation()
    local frame = self:getCurrentThread():getCallStack():getFrame()
    assert(frame, "callstack empty; cannot enter logical evaluation mode")

    frame:enterLogicalEvaluation()
end

function Flow:leaveLogicalEvaluation()
    local frame = self:getCurrentThread():getCallStack():getFrame()
    assert(frame, "callstack empty; cannot leave logical evaluation mode")

    frame:leaveLogicalEvaluation()
end

function Flow:getCurrentStringEvaluationPointer()
    return self._outputStackStringPointers[#self._outputStackStringPointers] or 0
end

function Flow:startStringEvaluation()
    if not self:getIsInExpressionEvaluation() then
        error("expected to be in logical evaluation mode")
    end

    self:leaveLogicalEvaluation()

    table.insert(self._outputStackStringPointers, self._outputStack:getCount())
end

function Flow:stopStringEvaluation()
    if self:getIsInExpressionEvaluation() then
        error("expected to NOT be in logical evaluation mode")
    end

    local index = table.remove(self._outputStackStringPointers) + 1
    local result = self._outputStack:toString(index, -1)
    self._outputStack:pop(self._outputStack:getCount() - index + 1)

    self._evaluationStack:push(result)
    self:enterLogicalEvaluation()
end

function Flow:enterTag()
    table.insert(self._outputStackTagIndices, self._outputStack:getCount())
end

function Flow:leaveTag()
    if #self._outputStackTagIndices == 0 then
        return
    end

    local startIndex = table.remove(self._outputStackTagIndices) + 1

    local result = self._outputStack:toString(startIndex, -1)
    self._tagStack:push(Value(Constants.TYPE_TAG, result))

    local count = self._outputStack:getCount() - startIndex + 1
    self._outputStack:pop(count)
end

function Flow:clean()
    while #self._threads > self._top do
        table.remove(self._threads, #self._threads)
    end

    while #self._choices > self._choiceCount do
        table.remove(self._choices, #self._choices)
    end
end

function Flow:push()
    local previousThread = self._threads[self._top]

    local index = self._top + 1
    local thread = previousThread:copy(self._threads[index])

    self._threads[index] = thread
    self._top = index

    return thread
end

function Flow:fork(other)
    local previousThread = self._threads[self._top]
    return previousThread:copy(other)
end

function Flow:canPop()
    return self._top > 1
end

function Flow:pop()
    if self._top <= 1 then
        assert(self._top == 1, "there must always be a thread")
        error("cannot pop last thread in stack")
    end

    self._top = self._top - 1
end

function Flow:getThreadCount()
    return self._top
end

function Flow:getThread(index)
    index = index or -1
    if index < 0 then
        index = self._top + index + 1
    end

    if index < 1 or index > self._top then
        error("thread index out of bounds")
    end

    return self._threads[index]
end

function Flow:getCurrentThread()
    return self._threads[self._top]
end

function Flow:replaceCurrentThread(forkedThread)
    local currentThread = self:getCurrentThread()
    if forkedThread ~= self:getCurrentThread() then
        forkedThread:copy(currentThread)
    end
end

function Flow:addChoice(choicePoint)
    local index = self._choiceCount + 1

    local choice = self._choices[index]
    if not choice then
        choice = Choice(self._executor)
        self._choices[index] = choice
    end
    choice:create(choicePoint)

    Utility.clearTable(self._choiceTags)
    for i = 1, self._tagStack:getCount() do
        local tag = self._tagStack:pop():cast(Constants.TYPE_STRING)
        if tag then
            tag = Utility.cleanWhitespace(tag)
            table.insert(self._choiceTags, 1, tag)
        end
    end
    choice:addTags(self._choiceTags)

    self._choiceCount = index

    return choice
end

function Flow:getChoice(index)
    index = index or 1
    if index < 0 then
        index = self._choiceCount + index + 1
    end

    if index >= 1 and index <= self._choiceCount then
        return self._choices[index]
    end

    return nil
end

function Flow:clearChoices()
    self._choiceCount = 0
end

function Flow:getChoiceCount()
    return self._choiceCount
end

function Flow:done()
    if self:canPop() then
        self:pop()
    else
        self:stop()
    end
end

function Flow:stop()
    while self:canPop() do
        self:pop()
    end

    self:getCurrentThread():getCallStack():clear()
    self:clearChoices()
end

function Flow:step()
    local top = self._outputStack:peek()
    if not (top and top:is(Constants.TYPE_STRING) and top:getValue():find("\n$")) then
        self._previousTagCount = self._tagStack:getCount()
    end
end

function Flow:trimWhitespace(stackPointer)
    stackPointer = stackPointer or 0

    for i = self._outputStack:getCount(), 1, -1 do
        if not self._outputStack:isWhitespace(i, i) and not self._outputStack:peek(i):is(Constants.TYPE_GLUE) then
            break
        end

        if i <= stackPointer then
            break
        end

        self._outputStack:remove(i)
    end
end

function Flow:_findBreak(index)
    local pendingStart = index or 1
    local pendingStop = pendingStart

    while pendingStop < self._outputStack:getCount() do
        if not self._outputStack:isWhitespace(pendingStop, pendingStop) then
            break
        end

        pendingStop = pendingStop + 1
    end


    local hasGlue = false
    while pendingStop < self._outputStack:getCount() do
        if hasGlue and not self._outputStack:isWhitespace(pendingStop, pendingStop) then
            hasGlue = false
        end

        if not hasGlue and self._outputStack:toString(pendingStop, pendingStop):find("\n$") then
            break
        end

        if self._outputStack:peek(pendingStop):is(Constants.TYPE_GLUE) then
            hasGlue = true
        end

        pendingStop = pendingStop + 1
    end

    return pendingStart, pendingStop
end

--- Returns true if the flow is still waiting on valid output.
--- 
--- Generally, when the output stack looks like this:
--- 
--- (pending_text*)(whitespace_with_newline*)(next_text*)
--- 
--- Then the story should break and return current_text.
--- 
--- @return boolean
function Flow:shouldContinue()
    if #self._outputStackStringPointers >= 1 then
        return true
    end

    -- There is nothing in the output stack.
    if self._outputStack:getCount() == 0 then
        return true
    end

    -- Currently the entire output stack is just whitespace.
    if self._outputStack:isWhitespace() then
        return true
    end

    local _, pendingStop = self:_findBreak()
    local _, nextStop = self:_findBreak(pendingStop)

    if nextStop <= self._outputStack:getCount() and not (nextStop > pendingStop and self._outputStack:toString(nextStop, nextStop):find("\n$")) then
        return true
    end

    -- local _, currentStop, nextStart, nextStop = self:_findBreak()
    -- if currentStop > self._outputStack:getCount() then
    --     return true
    -- end

    -- if nextStop > self._outputStack:getCount() then
    --     return true
    -- end
    
    return false
end

function Flow:continue()
    Utility.clearTable(self._tags)

    for _ = 1, self._tagStack:getCount() do
        local tag = self._tagStack:pop(1):cast(Constants.TYPE_STRING)
        if tag then
            tag = Utility.cleanWhitespace(tag)
            table.insert(self._tags, 1, tag)
        end
    end

    local currentStart, currentStop = self:_findBreak()
    if self._outputStack:getCount() == 0 then
        self._currentText = ""
    else
        local text = self._outputStack:toString(currentStart, currentStop)
        for i = currentStop, currentStart, -1 do
            self._outputStack:remove(i)
        end

        self._currentText = Utility.cleanWhitespace(text) .. "\n"
    end
end

return Flow
