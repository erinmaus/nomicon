package.path = string.format("%s/?.lua;%s/?/init.lua;%s", love.filesystem.getSourceBaseDirectory(), love.filesystem.getSourceBaseDirectory(), package.path)

local IS_DEBUG = os.getenv("LOCAL_LUA_DEBUGGER_VSCODE") == "1"
if IS_DEBUG then
	require("lldebugger").start()

	function love.errorhandler(msg)
		error(msg, 2)
	end
end

local utility = require("utility")
local isCI = utility.getIsCI(...)

function love.conf(t)
    if isCI then
        t.modules.graphics = false
        t.modules.window = false
        t.modules.audio = false
    end

    t.identity = "Nomicon Demo"
    t.title = "Nomicon Tests"
end
