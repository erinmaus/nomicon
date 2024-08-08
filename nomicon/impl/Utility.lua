local function clearTable(t)
    if table.clear then
        table.clear(t)
        return t
    end

    while #t > 0 do
        table.remove(t, #t)
    end

    for key in pairs(t) do
        t[key] = nil
    end

    return t
end

local function cleanWhitespace(text)
    return text:gsub("^[\n\r%s]*", ""):gsub("[\n\r%s*]*[\n\r]?$", ""):gsub("([\t%s][\t%s]*)", " ")
end

local isLuaJIT = type(_G.jit) == "table"
local isLua52Plus = false
do
    if type(_VERSION) == "string" then
        local major, minor = _VERSION:match("Lua (%d)+.(%d)+")
        if major and minor then
            major = tonumber(major)
            minor = tonumber(minor)

            isLua52Plus = major >= 5 and minor >= 2
        end
    end
end

local function _xpcall(f, ...)
    if isLua52Plus or isLuaJIT then
        return xpcall(f, debug.traceback, ...)
    else
        local args = { ... }
        local n = select("#", ...)
        return xpcall(function()
            return f(unpack(args, 1, n))
        end, function(error)
            return debug.traceback(error, 3)
        end)
    end
end

return {
    clearTable = clearTable,
    cleanWhitespace = cleanWhitespace,
    xpcall = _xpcall
}
