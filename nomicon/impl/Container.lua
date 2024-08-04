local bit = require("bit")
local PATH = (...):gsub("[^%.]+$", "")
local ChoicePoint = require(PATH .. "ChoicePoint")
local Class = require(PATH .. "Class")
local Command = require(PATH .. "Command")
local Constants = require(PATH .. "Constants")
local Divert = require(PATH .. "Divert")
local NativeFunction = require(PATH .. "NativeFunction")
local Path = require(PATH .. "Path")
local Value = require(PATH .. "Value")
local Variable = require(PATH .. "Variable")

local Container = Class()

function Container:new(parent, name, object)
    self._parent = parent
    self._name = name
    self._object = object
    self._flags = object and object[#object] and object[#object][Constants.FIELD_CONTAINER_FLAGS] or 0
    self._path = Path(self)

    self._content = {}
    self._namedContent = {}

    self:_parse()
end

function Container:pointer(path)
    local _, container, index = self:_search(path)
    return container, index
end

function Container:search(path)
    local container = self:_search(path)
    return container
end

function Container:_search(path)
    local current
    if path:sub(1, 1) == "." then
        current = self
    else
        current = self._path:getContainer(1)
    end

    local previous, previousIndex
    local index = 1
    for pathComponent in path:gmatch("%.?([^%.]+)%.?") do
        previous = current
        previousIndex = nil

        if pathComponent == Constants.PATH_PARENT then
            if index > 1 then
                current = current:getParent()
            end
        elseif pathComponent:match("^(%d+)$") then
            previousIndex = tonumber(pathComponent) + 1
            current = current:getContent(previousIndex)
        else
            current = current:getContent(pathComponent)
        end

        index = index + 1

        if not current then
            return nil, nil, nil
        end
    end

    return current, previousIndex and previous or current, previousIndex or 1
end

function Container:getParent()
    return self._parent
end

function Container:getName()
    return self._name
end

function Container:getObject()
    return self._object
end

function Container:getPath()
    return self._path
end

function Container:getShouldCountVisits()
    return bit.band(self._flags, Constants.FLAG_CONTAINER_RECORD_VISITS) ~= 0
end

function Container:getShouldCountTurns()
    return bit.band(self._flags, Constants.FLAG_CONTAINER_TURN_INDEX) ~= 0
end

function Container:getShouldOnlyCountAtStart()
    return bit.band(self._flags, Constants.FLAG_CONTAINER_COUNT_START_ONLY) ~= 0
end

function Container:getCount()
    return #self._content
end

function Container:_toAbsoluteIndex(index)
    index = index or -1
    if index < 0 then
        index = #self._content + index + 1
    end
    return index
end

function Container:getContent(key)
    if type(key) == "number" then
        return self._content[self:_toAbsoluteIndex(key)]
    elseif type(key) == "string" then
        return self._namedContent[key]
    end

    return nil
end

function Container:_parseInstruction(index, instruction)
    if NativeFunction.isNativeFunction(instruction) then
        return NativeFunction(instruction)
    elseif Command.isCommand(instruction) then
        return Command(instruction)
    elseif Divert.isDivert(instruction) then
        return Divert(instruction)
    elseif Value.isValue(instruction) then
        return Value(nil, instruction, instruction)
    elseif Variable.isVariable(instruction) then
        return Variable(instruction)
    elseif ChoicePoint.isChoicePoint(instruction) then
        return ChoicePoint(self, instruction)
    elseif Container.isContainer(instruction) then
        return Container(self, index, instruction)
    end

    return nil
end

function Container:_addNamedContent(name, container)
    if self._namedContent[name] ~= nil then
        error(string.format("container '%s' has named content '%s'", self:getPath():toString(), name))
    end

    do
        local object = container:getObject()
        local objectName = object and type(object[#object]) == "table" and object[#object][Constants.FIELD_CONTAINER_NAME]
        assert(container:getName() == name or objectName == name, "container name mismatch")
    end

    self._namedContent[name] = container
end

function Container:_parseNamedContent(instruction)
    if type(instruction) ~= "table" or #instruction >= 1 then
        return
    end

    if instruction[Constants.FIELD_CONTAINER_NAME] and self:getParent() then
        self:getParent():_addNamedContent(instruction[Constants.FIELD_CONTAINER_NAME], self)
    end

    -- 'null' is lost, so we have to handle end of container differently
    local isContainer = true
    for _, value in pairs(instruction) do
        isContainer = isContainer and Container.isContainer(value)
        if not isContainer then
            break
        end
    end

    if not isContainer then
        return
    end

    for name, content in pairs(instruction) do
        local container = Container(self, name, content)
        self:_addNamedContent(name, container)
    end
end

function Container:_parse()
    for index, instruction in ipairs(self._object) do
        local content = self:_parseInstruction(index, instruction)

        if content == nil and index == #self._object then
            self:_parseNamedContent(instruction)
        elseif content then
            if Class.isDerived(Class.getType(content), Container) then
                local name = content:getObject()[Constants.FIELD_CONTAINER_NAME]
                if name then
                    self:_addNamedContent(name, content)
                end
            end

            table.insert(self._content, content)
        else
            error(string.format("could not parse instruction @ %s (%d)", self:getPath():toString(), index))
        end
    end
end

function Container:call(executor)
    local currentThread = executor:getCurrentFlow():getCurrentThread()
    local currentContainer = currentThread:getCurrentPointer()

    if currentContainer ~= self:getParent() then
        return
    end

    currentThread:getCallStack():jump(self, 0)
    executor:visit(self)
end

function Container.isContainer(instruction)
    return type(instruction) == "table" and #instruction >= 1
end

return Container
