local PATH = (...):gsub("[^%.]+$", "")
local Class = require(PATH .. "impl.Class")
local Container = require(PATH .. "impl.Container")
local Constants = require(PATH .. "impl.Constants")
local Executor = require(PATH .. "impl.Executor")
local GlobalVariables = require(PATH .. "impl.GlobalVariables")
local ListDefinitions = require(PATH .. "impl.ListDefinitions")
local Value = require(PATH .. "impl.Value")

--- @alias Nomicon.Value Nomicon.Impl.Value | Nomicon.Impl.Divert | Nomicon.Impl.List | Nomicon.Impl.Pointer | number | string | boolean

--- @class Nomicon.Story
--- @field private _executor Nomicon.Impl.Executor
--- @field private _book table
--- @field private _globalVariables Nomicon.Impl.GlobalVariables
--- @overload fun(book: table, defaultGlobalVariables: table?): Nomicon.Story
local Story = Class()

--- @param book table
--- @param defaultGlobalVariables table
function Story:new(book, defaultGlobalVariables)
    self._book = book

    self._globalVariables = GlobalVariables()
    if defaultGlobalVariables then
        for key, value in pairs(defaultGlobalVariables) do
            self._globalVariables:set(key, value)
        end
    end

    local listDefinitions = ListDefinitions(book.listDefs or {})
    local container = Container(nil, "root", book.root or {})

    self._executor = Executor(container, listDefinitions, self._globalVariables)

    local callStack = self._executor:getCurrentFlow():getCurrentThread():getCallStack()
    callStack:enter(Constants.DIVERT_START, self._executor:getRootContainer(), 1)
end

--- Configures the RNG for the story.
--- 
--- A default RNG implementation is provided when run in LÖVE with a global `love` table.
--- Otherwise, you will need you provide your own.
--- 
--- @param setSeedFunc fun(seed: integer) the function to set the current seed for the RNG
--- @param getSeedFunc fun(): number the function to get the current seed for the RNG
--- @param random fun(min: integer, max: integer): integer the function to return a random value given the current seed
function Story:setRandom(setSeedFunc, getSeedFunc, random)
    self._executor:setRandom(setSeedFunc, getSeedFunc, random)
end

--- Gets the current value of a global variable.
--- 
--- This does not have to be a global currently defined in the story.
--- 
--- @param variableName string the name of the global variable
--- @param marshal boolean? whether or not to convert to a native Lua type or return a Value object; defaults to true
--- @return Nomicon.Value value the value of global variable, or nil if unset
--- @see Nomicon.Impl.Value
function Story:getGlobalVariable(variableName, marshal)
    marshal = marshal == nil or marshal

    local value = self._executor:getGlobalVariable(variableName)
    if marshal then
        return value:getValue()
    end
    return value
end

--- Sets (or creates) a new global variable.
--- 
--- If the variable is not a Value, it will be marshalled to one internally.
--- Any global variable listeners **will not** be called with the new value.
--- 
--- @param variableName string the name of the global variable
--- @param value Nomicon.Value the value of the variable
function Story:setGlobalVariable(variableName, value)
    self._executor:setGlobalVariable(variableName, Value(nil, value), false)
end


--- @alias Nomicon.GlobalVariableListener fun(args...: any, key: string, value: Nomicon.Value, previousValue: Nomicon.Value) | fun(args...: any, value: Nomicon.Value, previousValue: Nomicon.Value)

--- Listen for a variable with the given name.
--- 
--- There are few neat things about func:
--- 1. Any arguments passed AFTER the last named argument will be passed FIRST to func.
---    This means you can bind a method by passing in 'func' and 'self'.
--- 2. When using "*", the key (variable name) will be provided as the first named argument.
--- 
--- @param variableName string|"*" the name of the global variable or "*" to listen for all global variables
--- @param func Nomicon.GlobalVariableListener the global variable listener
--- @param marshal boolean? true to marshal variables, false to use the Nomicon value; defaults to true
--- @param ... any these values are passed to the listener as the FIRST arguments
function Story:listenForGlobalVariable(variableName, func, marshal, ...)
    self._executor:getGlobalVariables():listen(variableName, func, marshal, ...)
end

--- Silences a global variable listener or listeners with the given name/func combo.
--- 
--- If "func" is TRUE, then **all** listeners for the given variable name will be removed.
---
--- @param variableName string|"*"
--- @param func Nomicon.GlobalVariableListener|boolean
function Story:silenceGlobalVariableListener(variableName, func)
    if func == true then
        self._executor:getGlobalVariables():remove(variableName)
    elseif type(func) ~= "boolean" then
        self._executor:getGlobalVariables():remove(variableName, func)
    end
end

--- Returns whether or not the story can continue.
---@return boolean canContinue true if the story can continue, false otherwise
function Story:canContinue()
    return self._executor:canContinue()
end

--- Continues the story.
--- 
--- Returns text and tags (if any).
--- 
--- @return string text the text
--- @return string[] tags the tags (if any) associated with the text
function Story:continue()
    local result = self._executor:continue()
    local tags = {}
    for i = 1, self._executor:getTagCount() do
        table.insert(tags, self._executor:getTag(i))
    end

    return result, tags
end

--- Returns true if the story has choices, false otherwise.
---@return boolean
function Story:hasChoices()
    return self:getChoiceCount() >= 1
end

--- Returns the number of choices currently available.
--- 
--- A choice must be made before the story continues.
--- 
--- @return integer choiceCount
function Story:getChoiceCount()
    return self._executor:getChoiceCount()
end

--- Returns the choice at the specific index.
--- @param index number the index of the choice; if negative, will wrap around from end (so -1 will return the last choice, while 1 returns the first)
--- @return Nomicon.Impl.Choice choice
function Story:getChoice(index)
    return self._executor:getChoice(index)
end

--- Makes a choice.
--- 
--- This will increment the turn count on success.
--- 
--- @param option Nomicon.Impl.Choice | string the choice or path to a knot
--- @return boolean result true if the choice was successful (ie was valid), false otherwise
function Story:choose(option)
    local success = self._executor:choose(option)
    if success then
        self._executor:incrementTurnCount()
    end

    return success
end

return Story
