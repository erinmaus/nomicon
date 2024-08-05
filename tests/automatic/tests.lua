local utility = require "utility"

local tests = utility.collectTests("automatic", ...)
utility.runTests(tests)
