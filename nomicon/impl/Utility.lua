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

return {
    clearTable = clearTable,
    cleanWhitespace = cleanWhitespace
}
