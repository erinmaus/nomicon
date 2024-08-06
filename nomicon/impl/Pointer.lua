local PATH = (...):gsub("[^%.]+$", "")
local Class = require(PATH .. "Class")
local Constants = require(PATH .. "Constants")

--- @class Nomicon.Impl.Pointer represents a pointer to a variable
--- @overload fun(object: table): Nomicon.Impl.Pointer
local Pointer = Class()

--- Constructs a new pointer from an object (instruction).
--- @param object table
function Pointer:new(object)
    self._variable = object[Constants.FIELD_VARIABLE_POINTER]
    self._contextIndex = object[Constants.FIELD_CONTEXT_INDEX] or -1
    self._object = object
end

--- Gets the name of the variable this Pointer points to.
--- @return string
function Pointer:getVariable()
    return self._variable
end

--- Gets the context index (index into the call stack of the current thread) that this pointer points to.
--- @return integer
function Pointer:getContextIndex()
    return self._contextIndex
end

--- Internal. Updates 'other' with a copy of this Pointer as well as an updated context index.
--- 
--- @param value integer
--- @param other Nomicon.Impl.Pointer
function Pointer:updateContextIndex(value, other)
    other = self:copy(other)
    other._contextIndex = value

    return other
end

--- Gets the object (instruction) representing this pointer
--- @return table
function Pointer:getObject()
    return self._object
end

--- Internal. Copies this Pointer to another Pointer.
--- @param other Nomicon.Impl.Pointer
--- @return Nomicon.Impl.Pointer pointer returns a reference to 'other'
function Pointer:copy(other)
    if other then
        other._variable = self._variable
        other._object = self._object
    else
        other = Pointer(self._object)
    end

    other._contextIndex = self._contextIndex

    return other
end

return Pointer
