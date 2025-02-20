local defs = require('definition')
local inspectlua = require('inspect')
local function inspect(...)
  local args = {...}
  for i = 1, select('#', ...) do
    print(inspectlua(args[i]))
  end
end

local insert = table.insert

---Output a warning to stdout.
---Sadly, those warnings are often ambiguous,
---and don't point to a line in input, the parsing happens in a
---line agonistic way.
local function warning(fmt, ...)
  if select('#', ...) > 0 then
    fmt = fmt:format(...)
  end
  print(fmt)
end

---@param str string
---@return string
local function trim(str)
  if type(str) ~= 'string' then
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
---@field type 'alias' | string?
---Some handlers might want to provide a "value" struct, see type for more info.
---@field value table?

---@alias line_type 'annotation' | 'description' | 'lua'

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

---@return types_ast?
local function parseTypes(content)
  return defs.types_capture:match(content)
end

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

  if not types then
    return warning('failed to parse types for param "%s"', name)
  end
  local type = {}
  for _, t in ipairs(types) do
    insert(type, t.type)
  end

  return {
    name = name,
    type = type,
    optional = opt,
    description = description,
  }
end

---@alias return_obj {name: string, types: {type: string}[], nilable: boolean, description?: string}

---@param val string
---@return return_obj[]
local function parseReturn(val)
  local rets = defs.returns:match(val) --[[@as returns_ast]]

  local returns = {}
  for _, ret in ipairs(rets) do
    local new_ret = {
      name = ret.name or '',
      types = {},
      nilable = false,
    }
    for _, type in ipairs(ret) do
      table.insert(new_ret.types, type.type)
      if type.type == 'nil' then
        new_ret.nilable = true
      end
    end
    table.insert(returns, new_ret)
  end
  returns.description = rets.description

  return returns
end

-- handles multi-line returns
---@param parsed_chunk parsed_chunk
---@param value return_obj[]
local function handleReturns(parsed_chunk, _, value)
  for i = 1, #value do
    local ret = value[i]
    ret.tag = 'return' --[[@diagnostic disable-line: inject-field]]
    insert(parsed_chunk.annotations, ret)
  end
end

local function parseAlias(val)
  -- match the alias name and the alias content
  -- note that this assumes valid name and content names
  -- and that if a description is provided it must have `#`
  local name, content = val:match('([^ ]+)%s*(.*)')
  name = name:match('[a-zA-Z_*%.][0-9a-zA-Z_*%.%-]*')
  content = parseDesc(content)

  -- split the types on `|`
  -- NOTE: this assumes that any | can be split which is not true
  -- for example `---@alias separator "." | "|"`.
  -- We just make sure to never use `|` in quotes...
  local types = parseTypes(content)

  return {name = name, types = types}
end

-- handles multi-line aliases
---@param parsed_chunk parsed_chunk
---@param line_type line_type
---@param val table|string|nil
local function handleAlias(parsed_chunk, line_type, val)
  -- if this is the first line in a multi-line alias, pass to the next
  if parsed_chunk.type ~= 'alias' then
    parsed_chunk.type = 'alias' -- TODO: do we really need this property? we can check if line_type ~= 'description'
    return true
  end
  -- we only want to handle description type
  if line_type ~= 'description' then
    return false
  end
  if not val then
    -- could happen in case an alias doesn't have a name(?)
    warning('broken alias detected, possibly missing name')
    parsed_chunk.type = nil -- unset
    -- TODO: we might want to reset the type to the older value
    -- of parsed_chunk.type instead of nil.
    return false
  end
  ---@cast val string

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
    parsed_chunk.value.types = parsed_chunk.value.types or {}
    insert(parsed_chunk.value.types, type)
    return true
  end

  if not parsed_chunk.value.types then
    warning('Alias "%s" does not have any types defined')
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
  ['return'] = parseReturn,
}

-- tags that we want to handle and are part of a section
local handled_tags = {
  alias = handleAlias,
  ['return'] = handleReturns,
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
      return 'annotation', parsed_tag
    end
    return warning('unhandled annotation tag @%s', tostring(tag))
  end

  local description = line:match('%-%-%-%s*(.*)')
  if description then
    return 'description', description
  end

  -- TODO: we might want to do something about comments starting with
  -- only two dashes, currently they are considered Lua lines
  -- I am not sure if they should become part of the description
  -- like LuaLS consider them to be, or completely ignore them.
  -- There are some complications that may arise if we want to support them,
  -- won't know for sure until the finish of the parser.

  return 'lua', line
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
    if not handler then
      return
    end
    local keep = handler(parsed_chunk, line_type, line_value)
    if not keep then
      handler = nil
    else
      if type(keep) == 'function' then
        handler = keep
        return handleTag(line_type, line_value)
      else
        return true
      end
    end
  end

  for _, line in ipairs(chunk) do
    local line_type, line_value = parseLine(line)
    -- p('line_type, line_value:', line_type, line_value) -- DEBUGGING

    if handleTag(line_type, line_value) then
      goto continue
    end

    if line_type == 'annotation' then
      ---@cast line_value table
      if terminator_tags[line_value.tag] then
        parsed_chunk.terminator[line_value.tag] = line_value
      elseif handled_tags[line_value.tag] then
        if parsed_chunk.value and parsed_chunk.type then
          warning('detected %s in the same chunk as another %s, overriding older definition!', line_value.tag, parsed_chunk.type)
        end
        parsed_chunk.value = line_value
        handler = handled_tags[line_value.tag]
        handleTag(line_type, line_value) -- handle initialization of parsed_chunk
      else
        insert(parsed_chunk.annotations, line_value)
      end
    elseif line_type == 'description' then
      insert(descriptions, line_value)
    else
      insert(parsed_chunk.lua, line_value)
    end

    ::continue::
  end

  parsed_chunk.description = table.concat(descriptions, '\n')
  return parsed_chunk
end

---@class Section
---@field namespace Namespace
local Section = {}

---@class ClassSection: Section
---@field type 'class'
---@field name string
---@field title string
---@field parents string[]
---@field aliases table[]
---@field methods table[]
---@field description string

---@class TextSection: Section
---@field type 'text'
---@field title string
---@field aliases table[]
---@field description string

---@return Section
function Section.new()
  return setmetatable({}, {__index = Section})
end

function Section:makeText(chunk)
  ---@cast self TextSection
  self.type = 'text'
  self.title = chunk.terminator.section.title
  self.aliases = {}
  self.description = chunk.description
end

function Section:makeClass(chunk)
  ---@cast self ClassSection
  self.type = 'class'
  self.name = chunk.terminator.class.name
  self.title = chunk.terminator.section.title
  self.parents = chunk.terminator.class.parents
  self.aliases = {}
  self.methods = {}
  self.description = chunk.description
end

---@return Section
function Section:flushSection(namespace)
  if next(self) then
    insert(namespace, self)
  end
  return Section.new()
end

---Ran when a type annotation comes before a variable declaration,
---such as @class and methods/functions definitions.
function Section:assignVariables(lines)
  for _, line in ipairs(lines) do
    local assignment = defs.assignment:match(line)
    if assignment then
      self.namespace.variables[assignment.var] = self
    end
  end
end

function Section:addMethod(parsed_chunk)
  if not self.methods then
    return
  end

  -- note: the language server only respects the first declaration as a proper cast
  local func_ast = defs.functions:match(parsed_chunk.lua[1])
  if not func_ast then
    return warning('failed to parse function declaration, skipping: "%s"', parsed_chunk.lua[1])
  end

  local method = {
    name = func_ast.name,
    description = parsed_chunk.description,
    method_form = func_ast.isMethod and (func_ast.class .. ':' .. func_ast.name) or nil,
    params = {},
    returns = {},
  }

  method.overloads = {}

  for _, annotation in ipairs(parsed_chunk.annotations) do
    if annotation.tag == 'param' then
      insert(method.params, {
        name = annotation.name,
        type = annotation.type,
        optional = annotation.optional,
        description = annotation.description,
      })
    elseif annotation.tag == 'return' then
      insert(method.returns, {
        name = annotation.name,
        types = annotation.types,
        nilable = annotation.nilable,
        description = annotation.description,
      })
    end
  end
  -- TODO: add overloads
  return insert(self.methods, method)
end

---@class Namespace
---@field sections Section[]
---@field variables table
---@field methods_map table
local Namespace = {}

function Namespace.new()
  return setmetatable({
    sections = {},
    variables = {},
    methods_map = {},
  }, {
    __index = Namespace
  })
end

function Namespace:newSection()
  local section = Section.new()
  section.namespace = self
  insert(self.sections, section)
  return section
end

function Namespace:finalizeSections()
  local sections = {}
  for _, section in ipairs(self.sections) do
    section.namespace = nil
    if next(section) then
      insert(sections, section)
    end
  end
  return sections
end

---@param chunks string[][]
local function parse(chunks)
  assert(type(chunks) == 'table', 'bad argument #1 to parse (expected table)')
  local namespace = Namespace.new()
  local section = namespace:newSection()

  for _, chunk in ipairs(chunks) do
    local parsed_chunk = parseChunk(chunk)

    -- handle terminator chunks, chunks that create
    -- a new section terminating previous one
    if next(parsed_chunk.terminator) then
      if parsed_chunk.terminator.namespace then
        if section.type then
          warning('a section was detected before a namespace was found!')
          section = namespace:newSection()
        end
        section:makeText(parsed_chunk)
      elseif parsed_chunk.terminator.class
      and parsed_chunk.terminator.section then
        section = namespace:newSection()
        section:makeClass(parsed_chunk)
        section:assignVariables(parsed_chunk.lua)
      elseif parsed_chunk.terminator.section then
        section = namespace:newSection()
        section:makeText(parsed_chunk)
      end
      goto continue
    elseif not section.type then
      warning('a chunk outside of any section was detected and will be ignored!')
      p(parsed_chunk)
      goto continue
    end

    -- handle other important chunks
    if parsed_chunk.type == 'alias' then
      insert(section.aliases, parsed_chunk.value)
    elseif parsed_chunk.lua[1] and parsed_chunk.lua[1]:match('^%s*function') then
      section:addMethod(parsed_chunk)
    end
    -- TODO MAIN 3: parse function groups and overloads

    ::continue::
  end

  return namespace:finalizeSections()
end

return {
  parseTypes = parseTypes,
  parseReturn = parseReturn,
  parse = parse,
}
