local chunks = require('scanner') [==[
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

---start galaxy forming, the longer the meowing the more galaxies going to form!
---@param meow number? # Defaults to 42
---@return boolean success, string? error_msg
function cat:meow(duration) end

]==]

local expected_tree = {
  {
    type = "class",
    name = "*universe.Main_Milkyway-Galaxy",
    title = "Main",
    description = "The main section of this entire world.\nContains the class of the main universe in the main galaxy.\nSurprise surprise, it has been all tables all the time!",
    parents = { "table" },
    aliases = {
      {
        name = "short-alias.important*",
        tag = "alias",
        types = {
          {
            type = "table[]"
          }
        }
      },
      {
        name = "long-alias.less_important",
        tag = "alias",
        types = {
          {
            description = "used when the world is shattering",
            type = '"CRITICAL"'
          },
          {
            description = "the worm is invading the universe :3!",
            type = "3"
          },
          {
            description = "^|^",
            type = "|"
          }
        }
      }
    },
    methods = {
      {
        description = "initialize a sub-universe, fill it with cats!",
        name = "new",
        overloads = {},
        params = {
          {
            description = "The Cat's Name",
            name = "name",
            optional = false,
            type = { "string" }
          }
        },
        returns = {
          {
            name = "",
            nilable = false,
            types = { "{[string]: integer}" }
          },
          {
            name = "error_msg",
            nilable = true,
            types = { "string", "nil" }
          },
          {
            name = "",
            nilable = true,
            types = { "long-alias.less_important", "nil" }
          }
        }
      },
      {
        description = "start galaxy forming, the longer the meowing the more galaxies going to form!",
        method_form = "cat:meow",
        name = "meow",
        overloads = {},
        params = {
          {
            description = "Defaults to 42",
            name = "meow",
            optional = false,
            type = { "number", "nil" }
          }
        },
        returns = {
          {
            name = "success",
            nilable = false,
            types = { "boolean" }
          },
          {
            name = "error_msg",
            nilable = true,
            types = { "string", "nil" }
          }
        }
      },
    },
  }
}


local parse = require('parser').parse
assert = require('luassert')

local parsed_tree = parse(chunks)
assert.same(expected_tree, parsed_tree)

