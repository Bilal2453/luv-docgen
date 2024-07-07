local re = require("re")

local insert = table.insert

---Output a warning to stdout.
---Sadly, those warnings are often ambiguous,
---and don't point to a line in input, the parsing happens in a
---line agonisting way. 
local function warning(fmt, ...)
  if select("#", ...) > 0 then
    fmt = fmt:format(...)
  end
  print(fmt)
end

---@param str string
---@return string
local function trim(str)
  if type(str) ~= "string" then
    return str
  end
  return (str:gsub('^%s*', ''):gsub('%s*$', ''))
end


--[[ Defining annotation tags parsers. ]] --[[

Each of those functions are mapped to a key in tags_parsers.
The key is a string value of the tag that when matched this
parser will be used for.

The parser will receive a string value representing the tag value,
for example for `---@param name string[]`, the parser will get "name string[]".

If the tag was also defined in handled_tags, a handler will be also called
on every new line in that chunk. If the handler is not interested in a line
it can return `false`/`nil` to allow for another parser/handler to take care of it,
otherwise if it wants to continue handling new lines it should return `true`.
If a handler wish to let another handler do the work, it may return a function
of the handler.
A handler is passed the parsed chunk struct, the line type, and the line value.

]]

---@class parsed_chunk
---A table holding Lua lines
---@field lua string[]
---A table holding as a key the name of a terminator tag
---that was found in this chunk, the value is the parsed tag.
---So see the value a parser returns for the structure.
---@field terminator {[string]: table}
---A table holding any unhandled parsed tags.
---@field annotations table[]
---A string that holds a description, empty string if none.
---@field description string
---Some handlers might want to provide a type, such as "alias".
---@field type "alias" | string?
---Some handlers might want to provide a "value" struct, see type for more info.
---@field value table?

---@alias line_type "annotation" | "description" | "lua"

local function pass()
  return {}
end

-- A ~~non~~ semi-working hack to parse in-line descriptions
-- such as "---@return integer # 1 for success!"
-- this works as far as `#` is used to imply the description
-- and as long as the description contains only one `#`.
-- For example this works: `@param name type | "#" # description`. 
-- But not this: `@param name type | "#" # # description`.
---@return string, string?
local function parseDesc(val)
  local content, desc
  if val:find('#') then
    content, desc = val:match('^(.+)#(.*)')
  end
  return trim(content or val), trim(desc)
end

local types_grammar = re.compile [=[
  types_capture <- {| types |}
  types <- %s* type %s* (optional / ('|' types))?
  type <- {| {:type: bracket_literal / value_literal :} |}

  optional <- {| {:type: '?' -> 'nil' :} |}

  value_literal <- number_literal / string_literal
  string_literal <- [^ ~!@#$%^&(){}/\;:,?]+
  number_literal <- '-'? [0-9]+

  bracket_literal <- {~ table_literal / array_literal / tuple_literal / fun_literal ~}
  table_literal <- '{' (bracket_literal / [^}])* '}'
  array_literal <- '[' (bracket_literal / [^]])* ']'
  tuple_literal <- '<' (bracket_literal / [^>])* '>'
  fun_literal   <- 'fun' %s* '(' (bracket_literal / [^)])* ')'
]=]

-- Parse union types into indivisual entries
-- ie turns `"string | integer[] | table<a, b>"` into 3 different entries.
---@return {type: string}[]
local function parseTypes(content)
  return types_grammar:match(content)
end
p(parseTypes("inb_4-2.etc | integer | {foo: fun(a: integer | string[])?, bar: integer | [1, 2, 3]}? | Class.Ignored"))


local function parseClass(val)
  local name, inheritance = val:match('([^ :]+)%s*:?%s*(.*)')
  local parents = {}
  if inheritance then
    for parent in inheritance:gmatch('[^ ,]+') do
      insert(parents, parent)
    end
  end
  return {
    name = name,
    parents = parents,
  }
end

local function parseParam(val)
  local name, opt, types = val:match('([^ ?]+)(%??)%s*(.+)')
  opt = opt ~= ''

  local description
  types, description = parseDesc(types)
  types = parseTypes(types)

  return {
    name = name,
    type = types,
    optional = opt,
    description = description,
  }
end

---@param val string
local function parseReturn(val)
  --[[ Take a deep breath... this is a ride
    calculate the last position of an "illegal" character
    and truncate it from the name, split the remaining by
    both | and space, if two tokens are not seperated by
    a | character, truncate the first one into type strings
    and treat the remaining as the name, otherwise continue
    until we find the last remaining term if it does exists.
    This is *some type* of "static analysis" that lets us
    do this parsing with having to actually properly parse it!
    
    Take for example the input "{[string]: integer} | string | integer value_rtn"
    1: `}` is the last illegal character that can be found, truncate
      the input into just "| string | integer value_rtn".
      The truncated string is going to be the types!
    2: split by `|`, we get {'', 'string', 'integer value_rtn'}.
    3: add all entries to the types string, consider the last entry.
    4: split the last entry by spaces, we get {'integer', 'value_rtn'}
    5: if we only got one entry back, that is a type, if we get a second
      that is going to be the name (we ignore the rest!).
  ]]

  -- TODO MAIN: I just realized we have to support multi returns

  -- truncate the description first
  local body, description = parseDesc(val)
  -- try to find the position of the last illegal char if any
  local type_str, remaining = body:match('(.+[%[%]{}<>:"\'`]%s*%??)(.*)')
  local rem_types, name
  if body:find('|') then
    rem_types, name = (remaining or body):match('(.+|%s*[^ ]+)%s*([^ ]*)')
  else
    rem_types, name = (remaining or body):match('(.+)%s+([^ ]*)')
  end
  if not type_str and not rem_types then
    type_str = body
  end
  name = name or trim(remaining)

  local types = {}
  parseTypes(type_str, types)
  parseTypes(rem_types, types)

  local isNilable = false
  for _, t in ipairs(types) do
    if t.type == 'nil' then
      isNilable = true
      break
    end
  end

  if name and name:find(',') then
    print("multi-return detected in ", name)
  end

  return {
    name = name or '',
    types = types,
    nilable = isNilable,
    description = description,
  }
end

-- Note: I wanted to use this grammar to parse aliases but then I realized
-- it wouldn't work, as I would need to handle a ton of special cases
-- for `type`, such as `table<a,b>`, `integer[][][]`, quotes, escapes, generics, etc.
-- it would be A TON of work for just this.
-- local alias_grammar = re.compile([[
--   alias         <- {| name sp types? |}
--   types         <- {:types:  {| ({| type |} / or)+ optional_type |} :}
--   optional_type <- ( {| {:type: '?' -> 'nil' :} |})?
--   type          <- {:type: [^ ]+ :}
--   name          <- {:name: word :}
--
--   or      <- sp '|' sp
--   word <- { ([^%p ] / ["*._-])+ }
--   sp <- ' '*
-- ]])
local function parseAlias(val)
  -- match the alias name and the alias content
  -- note that this assumes valid name and content names
  -- and that if a description is provided it must have `#`
  local name, content = val:match('([^ ]+)%s*(.*)')
  name = name:match('[a-zA-Z_*%.][0-9a-zA-Z_*%.%-]*')
  content = parseDesc(content)

  -- split the types on `|`
  -- NOTE: this assumes that any | is splitable which is not true
  -- for example `---@alias seperator "." | "|"`.
  -- We just make sure to never use `|` in quotes...
  local types = parseTypes(content)

  return {name = name, types = types}
end

-- handles multi-line aliases
---@param parsed_chunk parsed_chunk
---@param line_type line_type
local function handleAlias(parsed_chunk, line_type, val)
  -- if this is the first line, pass to the next
  if parsed_chunk.type ~= "alias" then
    parsed_chunk.type = "alias"
    return true
  end
  -- we only want to handle description type
  if line_type ~= "description" then
    return false
  end
  local value = parsed_chunk.value
  if not value then
    -- could happen in case an alias doesn't have a name(?)
    warning("a broken alias detected, possibly missing name")
    parsed_chunk.type = nil -- unset
    -- TODO: we might want to reset the type to the older value
    -- of parsed_chunk.type instead of nil.
    return false
  end

  -- handle non-description type lines, such as in:
  -- ---| integer
  if val:sub(1, 1) == '|' then
    local type = {}
    local isDefault, content = val:match('^|%s*(>?)%s*(.+)')
    if isDefault ~= '' then
      type.default = true
    end
    type.type, type.description = parseDesc(content)

    -- the inline description (ex `---|"val" # this is inline desc`)
    -- can only be used if there isn't a description above it as in:
    -- ---This is main description of the below
    -- ---|"val" # this here will be ignored by LuaLS
    -- TODO: do we want to consider inline description anyways?
    if parsed_chunk.value.cached_description then
      type.description = table.concat(parsed_chunk.value.cached_description, '\n')
      parsed_chunk.value.cached_description = nil
    end
    insert(parsed_chunk.value.types, type)
    return true
  end

  -- handle description lines
  -- we cache the description and use it
  -- when we hit the `|` line in the above route
  local description = parsed_chunk.value.cached_description or {}
  if not parsed_chunk.value.cached_description then
    parsed_chunk.value.cached_description = description
  end
  insert(description, val)
  return true
end

local function parseSection(val)
  return {title = val:match('.*') or ''}
end

local tags_parsers = {
  namespace = pass, -- TODO: do we really need to consider anything here?
  section = parseSection,
  class = parseClass,
  param = parseParam,
  alias = parseAlias,
  ["return"] = parseReturn,
}

-- tags that we want to handle and are part of a section
local handled_tags = {
  alias = handleAlias,
}

-- tags that when reached, marks the start of a new section
local terminator_tags = {
  namespace = true,
  section = true,
  class = true,
}


--[[ Parsers that operate on the chunks ]] --[[
todo
]]

---Given the name of a tag and its value, attempt to parse it if we can.
---`tag` is something like `"param"`, and `value` is everything after the name.
---
---This makes use of one of the parsers defined in `tags_parsers`,
---and passes it the `value`, returning whatever table the parser returns
---plus adding a `tag` field to it that is set to `tag` parameter.
---@param tag string
---@param value? string
---@return {[string]: any, tag: string}?
local function parseTag(tag, value)
  if tags_parsers[tag] then
    local parsed_tag = tags_parsers[tag](value)
    parsed_tag.tag = tag
    return parsed_tag
  end
end

---Given an annotation line, parse it and return its type and value.
---
---There are three possibilities:
--- - the line is an annotation (like @param).
--- - the line is a description (a comment line ---).
--- - the line is a Lua code, if the previous two don't match.
---@param line string
---@return line_type | nil type
---@return string | table | nil value
local function parseLine(line)
  local tag, value = line:match('%-%-%-%s*@([^ ]+)%s*(.*)')
  if tag then
    local parsed_tag = parseTag(tag, value)
    if parsed_tag then
      return "annotation", parsed_tag
    end
    return warning("unhandled annotation tag @%s", tostring(tag))
  end

  local description = line:match('%-%-%-%s*(.*)')
  if description then
    return "description", description
  end

  -- TODO: we might want to do something about comments starting with
  -- only two dashes, currently they are considered Lua lines
  -- I am not sure if they should become part of the description
  -- like LuaLS consider them to be, or completely ignore them.
  -- There are some complications that may arise if we want to support them,
  -- won't know for sure until the finish of the parser.

  return "lua", line
end



---@param chunk string[]
local function parseChunk(chunk)
  ---@type parsed_chunk
  local parsed_chunk = {
    lua = {},
    terminator = {},
    annotations = {},
    description = '',
  }
  local descriptions = {} -- a buffer for description lines

  local handler
  local function handleTag(line_type, line_value)
    if handler then
      local keep = handler(parsed_chunk, line_type, line_value)
      if not keep then
        handler = nil
      else
        if type(keep) == "function" then
          handler = keep
          return handleTag(line_type, line_value)
        else
          return true
        end
      end
    end
  end

  for _, line in ipairs(chunk) do
    local line_type, line_value = parseLine(line)
    p(line_type, line_value) -- DEBUGGING

    if handleTag(line_type, line_value) then
      goto continue
    end

    if line_type == "annotation" then
      ---@cast line_value table
      if terminator_tags[line_value.tag] then
        parsed_chunk.terminator[line_value.tag] = line_value
      elseif handled_tags[line_value.tag] then
        if parsed_chunk.value then
          warning("detected %s in the same chunk as another %s, overriding older definition!", line_value.tag, parsed_chunk.type)
        end
        parsed_chunk.value = line_value
        handler = handled_tags[line_value.tag]
        handleTag(line_type, line_value) -- handle initialization of parsed_chunk
      else
        insert(parsed_chunk.annotations, line_value)
      end
    elseif line_type == "description" then
      insert(descriptions, line_value)
    else
      insert(parsed_chunk.lua, line_value)
    end

    ::continue::
  end

  parsed_chunk.description = table.concat(descriptions, '\n')
  return parsed_chunk
end

local function makeText(section, chunk)
  section.type = "text"
  section.title = chunk.terminator.section.title
  section.aliases = {}
  section.description = chunk.description
end

local function makeClass(section, chunk)
  section.type = "class"
  section.name = chunk.terminator.class.name
  section.title = chunk.terminator.section.title
  section.parents = chunk.terminator.class.parents
  section.aliases = {}
  section.methods = {}
  section.description = chunk.description
end

local function flushSection(section, namespace)
  insert(namespace, section)
  return {}
end

---@param chunks string[][]
local function parse(chunks)
  assert(type(chunks) == "table", "bad argument #1 to parse (expected table)")
  local rtn = {}
  local section = {}

  for _, chunk in ipairs(chunks) do
    local parsed_chunk = parseChunk(chunk)
    p(parsed_chunk)

    -- handle terminator chunks, chunks that create
    -- a new section terminating previous one
    if next(parsed_chunk.terminator) then
      if parsed_chunk.terminator.namespace then
        if section.type then
          warning("a section was detected before a namespace was found!")
          section = flushSection(section, rtn)
        end
        makeText(section, parsed_chunk)
      elseif parsed_chunk.terminator.class
      and parsed_chunk.terminator.section then
        section = flushSection(section, rtn)
        makeClass(section, parsed_chunk)
      elseif parsed_chunk.terminator.section then
        section = flushSection(section, rtn)
        makeText(section, parsed_chunk)
      end
      goto continue
    elseif not section.type then
      warning("a chunk outside of any section was detected and will be ignored!")
      p(parsed_chunk)
      goto continue
    end

    -- handle other important chunks
    if parsed_chunk.type == "alias" then
      insert(section.aliases, parsed_chunk.value)
    -- elseif parsed_chunk.type == "functions" then
    end
    -- TODO MAIN: parse function groups, classes methods and overloads

    ::continue::
  end
  flushSection(section, rtn)

  return rtn
end

return {
  parseReturn = parseReturn,
  parse = parse,
}
