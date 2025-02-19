assert = require('luassert')

local chunks = require('scanner') [==[
---This is a magical description of a
---secret function in the first chunk!
---@param foo string
function magic1(foo) end
object.magicalMethod = magic1

another_assignment = true -- This is NOT part of the previous chunk because it is separated by two line endings

---This is the 2nd chunk!
---This chunk has two lines only. The minimum lines a chunk can have is 1.

-- this is not a chunk because it doesn't begin with three dashes ---
function ignored() end

---@param p1 string
---@param p2? number # description!
---@return table
function tbl.base(p1, p2) end
---@param p1 string
---@return boolean
function tbl.base(p1) end
]==]

local expected_chunks = {
  { '---This is a magical description of a', '---secret function in the first chunk!', '---@param foo string', 'function magic1(foo) end', 'object.magicalMethod = magic1' },
  { '---This is the 2nd chunk!', '---This chunk has two lines only. The minimum lines a chunk can have is 1.' },
  { '---@param p1 string', '---@param p2? number # description!', '---@return table', 'function tbl.base(p1, p2) end' },
  { '---@param p1 string', '---@return boolean', 'function tbl.base(p1) end' },
}

assert.same(expected_chunks, chunks)
