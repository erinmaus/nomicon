local function getIsCI(...)
    for i = 1, select("#", ...) do
        arg = select(i, ...)
        arg = type(arg) == "string" and arg:lower()

        if arg == "ci=yes" then
            return true
        elseif arg == "ci=no" then
            return false
        end
    end
end

return {
    getIsCI = getIsCI
}
