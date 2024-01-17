-- Tokenize the annotations into sections
-- this is a first run of this tokenizer
-- the aim is by the end of this to have a tokenizer
-- the works for all of luvit-meta.
-- Depends on LPeg.

-- The tokenizer works on chunks of annotations
-- a chunk of annotation is any number of adjacent lines
-- starting with three dashes `---` followed by
-- any number of Lua code, often function deftinion.
-- The next chunk starts at the next three dashes.
-- For example the following block has two chunks
--[[

---This is a magical description
---of a secret function!
---@param foo string
function magic1(foo) end
object.magicalMethod = magic1

---This is the 2nd chunk!
---This chunk has two lines only.

-- this is not a chunk because it doesn't begin with three dashes ---
function ignored() end
]]

-- Lines inside a single chunk MUST NOT be seperated
-- by more than one line ending.

-- A line ending character MUST be `\n`.

-- Chunks MUST be seperated by two or more line endings.

-- There MUST exists a trailing line ending at the end of the string
-- of the annotations (at the end the annotations file).

-- The order in which the chunks are defined is always preserved.

-- TODO: a rundown of the tokenization process
-- expected inputs and outputs

local compile = require('re').compile

local CHUNK_GRAMMAR = compile [[
  chunks  <- {| chunk+ |}
  chunk   <- {| comment+ line* |} / continue
  comment <- {'---'  [^%nl]* } %nl
  line    <- !'--' { [^%nl]+ } %nl

  continue <- [^%nl]+ / .
]]

---Given string of annotations, return an array of chunks.
---A single chunk is an array of lines the chunk is arranged of.
---@param str string
---@return string[][]
local function chunk(str)
  return CHUNK_GRAMMAR:match(str)
end

return chunk
