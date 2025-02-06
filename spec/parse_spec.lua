
local chunks = require'../scanner' [==[
---The main section of this entire world.
---@section Main
---Contains the class of the main universe in the main galaxy.
---Surprise surprise, it has been all tables all the time!
---@class *universe.Main_Milkyway-Galaxy: table
local cat = {}

---@alias short-alias.important* table[] # useless description

---@alias long-alias.less_important
--- | "CRITICAL"   # used when the world is shattering
---the worm is invading the universe :3!
---| 3
---|     |         # ^|^

---initialize a sub-universe, fill it with cats!
---@param name string # The Cat's Name
---@return {[string]: integer}
---@return string? error_msg # Good Luck
---@return long-alias.less_important?
function cat.new(name) end

]==]

---@class test: table
local tbl = {}

local parse = require '../parser'.parse

local rtn = parse(chunks)
print '----------------------'
print(require('inspect').inspect(rtn))
print '----------------------'
