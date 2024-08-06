local PATH = (...):gsub("[^%.]+$", "")
local Class = require(PATH .. "impl.Class")
local Container = require(PATH .. "impl.Container")
local Constants = require(PATH .. "impl.Constants")
local Executor = require(PATH .. "impl.Executor")
local GlobalVariables = require(PATH .. "impl.GlobalVariables")
local ListDefinitions = require(PATH .. "impl.ListDefinitions")
local Value = require(PATH .. "impl.Value")
local InstructionBuilder = require(PATH .. "impl.InstructionBuilder")

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

    self._executor = Executor(self._globalVariables)

    local listDefinitions = ListDefinitions(book.listDefs or {})
    self._executor:setListDefinitions(listDefinitions)

    local container = Container(nil, "root", book.root or {}, InstructionBuilder(self._executor))
    self._executor:setRootContainer(container)

    self:_loadGlobals()
    self:_loadGlobalTags()

    local callStack = self._executor:getCurrentFlow():getCurrentThread():getCallStack()
    callStack:enter(Constants.DIVERT_START, self._executor:getRootContainer(), 1)
end

--- Gets the global list definitions.
--- 
--- You can use this to interop with list types.
--- 
--- @return Nomicon.Impl.ListDefinitions
function Story:getListDefinitions()
    return self._executor:getListDefinitions()
end

function Story:_loadGlobals()
    local globals = self._executor:getRootContainer():getContent(Constants.GLOBAL_VARIABLES_NAMED_CONTENT)
    if globals then
        self._executor:getCurrentFlow():getCurrentThread():getCallStack():enter(Constants.DIVERT_START, globals, 0)
        self._executor:continue()
        self._executor:stop()

        assert(not self._executor:canContinue(), "global variable initialization container bad")
    end
end

function Story:_loadGlobalTags()
    local TEMP_FLOW_NAME = {}
    self._executor:newFlow(TEMP_FLOW_NAME)
    self._executor:switchFlow(TEMP_FLOW_NAME)

    local callStack = self._executor:getCurrentFlow():getCurrentThread():getCallStack()
    callStack:enter(Constants.DIVERT_START, self._executor:getRootContainer(), 1)

    self:continue()

    self._globalTags = {}
    for i = 1, self._executor:getTagCount() do
        table.insert(self._globalTags, self._executor:getTag(i))
    end

    self._executor:deleteFlow(TEMP_FLOW_NAME)
    self._executor:resetCount()
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
    self._executor:setGlobalVariable(variableName, Value(nil, value))
end


--- @alias Nomicon.GlobalVariableListener fun(args...: any, key: string, value: Nomicon.Value, previousValue: Nomicon.Value): any | fun(args...: any, value: Nomicon.Value, previousValue: Nomicon.Value): any

--- Listen for a variable with the given name.
--- 
--- There are few neat things about func:
--- 1. Any arguments passed AFTER the last named argument will be passed FIRST to func.
---    This means you can bind a method by passing in 'func' and 'self'.
--- 2. When using "*", the key (variable name) will be provided as the first named argument.
--- 
--- If the function returns a value, this will override the value of the assignment.
--- Only the last registered listener that returns a value can override the return value.
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

--- Returns true if there is an external function with the given name, false otherwise.
--- 
--- @param name string name of the external function 
--- @return boolean exists
function Story:hasExternalFunction(name)
    return self._executor:hasExternalFunction(name)
end

--- Frees an external function with the provided name.
--- 
--- @param name string name of the external function to free
--- @return boolean success returns true if the external function was freed, false otherwise
function Story:freeExternalFunction(name)
    return self._executor:freeExternalFunction(name)
end

--- Binds the external function to a given name. Any extra parameters are passed as the first arguments to func, followed by the arguments from the call in Ink.
--- 
--- @param name string name of the external function
--- @param func function function to call with the 
--- @param marshal boolean? true if values should be marshalled from Nomicon.Impl.Value, false otherwise; defaults to true if not provided (ie is nil)
--- @param ... any
--- @return boolean success returns true if the external function was bound, false otherwise. Will fail if an external fucntion with the name already exists.
function Story:bindExternalFunction(name, func, marshal, ...)
    return self._executor:bindExternalFunction(name, func, marshal, ...)
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
--- @return boolean
function Story:hasChoices()
    return self:getChoiceCount() >= 1
end

--- Returns the number of choices currently available.
--- 
--- A choice must be made before the story continues.
--- 
--- This will return unselectable choices as well. For easier management of just selectable and visible choices.
--- use ChoiceList.
--- 
--- @return integer choiceCount
--- @see Nomicon.ChoiceList
function Story:getChoiceCount()
    return self._executor:getChoiceCount()
end

--- Returns the choice at the specific index.
---
--- This will return unselectable choices as well. For easier management of just selectable and visible choices.
--- use ChoiceList.
--- 
--- @param index number the index of the choice; if negative, will wrap around from end (so -1 will return the last choice, while 1 returns the first)
--- @return Nomicon.Impl.Choice choice
--- @see Nomicon.ChoiceList
function Story:getChoice(index)
    return self._executor:getChoice(index)
end

--- Returns the number of tags on the text.
--- @return number tagCount
function Story:getTagCount()
    return self._executor:getTagCount()
end

--- Returns the tag at the specific index.
---
--- Negative values wrap backwards. So -1 will return the last tag in the list.
--- 
--- @return string tag text of the tag
function Story:getTag(index)
    if index < 0 then
        index = index + self:getTagCount() + 1
    end

    return self._executor:getTag(index)
end

--- Returns the number of global tags on the story.
--- @return number tagCount
function Story:getGlobalTagCount()
    return #self._globalTags
end

--- Returns the global tag at the specific index.
---
--- Negative values wrap backwards. So -1 will return the last global tag in the list.
---
--- @return string tag text of the global tag
function Story:getGlobalTag(index)
    if index < 0 then
        index = index + #self._globalTags + 1
    end

    return self._globalTags[index]
end

--- Gets the tags for the knot or container at the provided path.
--- @param path string the path to the knot or container
function Story:getTags(path)
    local TEMP_FLOW_NAME = {}
    self._executor:newFlow(TEMP_FLOW_NAME)
    self._executor:switchFlow(TEMP_FLOW_NAME)

    local callStack = self._executor:getCurrentFlow():getCurrentThread():getCallStack()
    callStack:enter(Constants.DIVERT_START, self._executor:getRootContainer(), 1)
    self._executor:choose(path)

    self:continue()

    local tags = {}
    for i = 1, self._executor:getTagCount() do
        table.insert(tags, self._executor:getTag(i))
    end

    self._executor:deleteFlow(TEMP_FLOW_NAME)
    return tags
end

--- Makes a choice.
--- 
--- This will increment the turn count on success.
--- 
--- @param option Nomicon.Impl.Choice | string the choice or path to a knot (or container, if you dare...)
--- @return boolean result true if the choice was successful (ie was valid), false otherwise
function Story:choose(option)
    local success = self._executor:choose(option)
    if success then
        self._executor:incrementTurnCount()
    end

    return success
end

return Story
