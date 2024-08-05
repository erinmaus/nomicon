local PATH = (...):gsub("[^%.]+$", "")
local ChoicePoint = require(PATH .. "ChoicePoint")
local Class = require(PATH .. "Class")
local Command = require(PATH .. "Command")
local Container = require(PATH .. "Container")
local Divert = require(PATH .. "Divert")
local List = require(PATH .. "List")
local NativeFunction = require(PATH .. "NativeFunction")
local Value = require(PATH .. "Value")
local Variable = require(PATH .. "Variable")

local InstructionBuilder = Class()

function InstructionBuilder:new(executor)
    self._executor = executor
end

function InstructionBuilder:parse(container, index, instruction)
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
        return Container(container, index, instruction, self)
    elseif List.isList(instruction) then
        return self._executor:getListDefinitions():newListFromObject(instruction)
    end

    return nil
end

return InstructionBuilder
