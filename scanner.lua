-- Depends on LPeg.

-- Scan the input into annotation sections
-- this is a first run of this scanner
-- the aim is by the end of this to have a scanner
-- the works for all of luvit-meta.

-- The scanner works on chunks of annotations
-- a chunk of annotation is any number of adjacent lines
-- starting with three dashes `---` followed by
-- any number of Lua code, often function definition.
-- The next chunk starts at the next three dashes.
-- For examples see spec/scanner_spec.lua.

-- Specs:
-- Lines inside a single chunk MUST NOT be separated
-- by more than one line ending.
--
-- A line ending character MUST be `\n`.
--
-- Chunks MUST be separated by two or more line endings.
--
-- There MUST exists a trailing line ending at the end of the string
-- of the annotations (at the end the annotations file).
--
-- The order in which the chunks are defined is always preserved.

-- TODO: C comments support

local compile = require('re').compile

local CHUNK_GRAMMAR = compile[[
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
