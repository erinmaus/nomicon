local utility = require "utility"

local tests = utility.collectTests("simple", ...)
utility.runTests(tests)
