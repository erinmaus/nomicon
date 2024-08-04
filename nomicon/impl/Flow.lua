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
    self._evaluationStack = ValueStack()
    self._outputStack = ValueStack()

    self._logicalEvaluationDepth = 0
    self._evaluationStackStringIndices = {}
    self._evaluationStackTagIndices = {}

    self._choices = {}
    self._choiceCount = 0

    self._tags = {}
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

function Flow:startStringEvaluation()
    if not self:getIsInExpressionEvaluation() then
        error("expected to be in logical evaluation mode")
    end

    self:leaveLogicalEvaluation()

    table.insert(self._evaluationStackStringIndices, self._outputStack:getCount())
end

function Flow:stopStringEvaluation()
    if self:getIsInExpressionEvaluation() then
        error("expected to NOT be in logical evaluation mode")
    end

    if #self._evaluationStackStringIndices == 0 then
        error("not currently in string evaluation mode")
    end

    local startIndex = table.remove(self._evaluationStackStringIndices, #self._evaluationStackStringIndices) + 1
    local stopIndex = self._outputStack:getCount()

    local result = self._outputStack:toString(startIndex, stopIndex)
    self._evaluationStack:push(Value(nil, result))

    local count = stopIndex - startIndex + 1
    self._outputStack:pop(count)

    self:enterLogicalEvaluation()
end

function Flow:enterTag()
    table.insert(self._evaluationStackTagIndices, self._evaluationStack:getCount())
end

function Flow:leaveTag()
    if #self._evaluationStackTagIndices == 0 then
        error("not currently in tag mode")
    end

    local startIndex = table.remove(self._evaluationStackTagIndices, #self._evaluationStackTagIndices)
    local stopIndex = self._evaluationStack:getCount()

    local result = self._evaluationStack:toString(startIndex, stopIndex)
    self._evaluationStack:push(Value(Constants.TYPE_TAG, result))

    local count = stopIndex - startIndex + 1
    self._evaluationStack:pop(count)
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

function Flow:continue()
    Utility.clearTable(self._tags)

    local index = self._outputStack:getCount()
    while index >= 1 and self._outputStack:peek(index):cast(Constants.TYPE_STRING) == "\n" do
        index = index - 1
    end

    while index >= 1 and self._outputStack:peek(index):is(Constants.TYPE_TAG) do
        table.insert(self._tags, self._outputStack:peek(index):cast(Constants.TYPE_STRING))
        index = index - 1
    end

    if index < 1 then
        self._currentText = ""
    else
        local text = self._outputStack:toString(1, index)
        self._currentText = text:gsub("^[\n\r%s]*", ""):gsub("[\n\r%s*]*[\n\r]?$", ""):gsub("([\t%s][\t%s]*)", " ") .. "\n"
    end
end

return Flow
