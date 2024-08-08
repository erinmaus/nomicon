local IS_DEBUG = os.getenv("LOCAL_LUA_DEBUGGER_VSCODE") == "1"
if IS_DEBUG then
	require("lldebugger").start()

	function love.errorhandler(msg)
		error(msg, 2)
	end
end

function love.conf(t)
    t.identity = "Nomicon Demo"
	t.title = "Nomicon Demo"
end
