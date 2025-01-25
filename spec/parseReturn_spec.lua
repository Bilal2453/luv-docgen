local parseReturn = require('../parser').parseReturn

package.path = package.path .. ';/usr/share/lua/5.4/?.lua;/usr/share/lua/5.4/?/init.lua;/usr/lib64/lua/5.4/?.lua;/usr/lib64/lua/5.4/?/init.lua;./?.lua;./?/init.lua;/home/bilal/.luarocks/share/lua/5.4/?.lua;/home/bilal/.luarocks/share/lua/5.4/?/init.lua'
assert = require("luassert")

-- single return
do
  assert.same(parseReturn('string? error_msg'), {
  types = {
    {type = "string"},
    {type = "nil"},
  },
  name = "error_msg",
  nilable = true,
})
assert.same(parseReturn('{[string]: integer?}?'), {
  types = {
    {type = "{[string]: integer?}"},
    {type = "nil"},
  },
  name = '',
  nilable = true,
})
assert.same(parseReturn('string | number error_msg'), {
  types = {
    {type = "string"},
    {type = "number"},
  },
  name = 'error_msg',
  nilable = false,
})
assert.same(parseReturn('long-alias.less_important'), {
  types = {
    {type = "long-alias.less_important"},
  },
  name = '',
  nilable = false,
})
end

-- do -- multi-returns
--   assert.same(parseReturn('first-return with_name, second.return, third_return'), {
--     types = {
--       {type = "long-alias.less_important"},
--     },
--     name = '',
--     nilable = false,
--   })
-- end

-- multi-returns
do
  p(parseReturn('0|nil success, string? err_name, string? err_msg'))
  p(parseReturn('string? no, boolean error'))
  p(parseReturn('t1 name, t2 | t3 name2'))
  p(parseReturn('table<a, b> tuple, {complex: true} complex, boolean simple'))
end
os.exit(0)