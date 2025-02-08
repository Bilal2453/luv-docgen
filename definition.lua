local re = require('re')

---@diagnostic disable: assign-type-mismatch
---@type {[string]: lpeg-pattern}
local defs = setmetatable({}, {
  __newindex = function(t, k, v)
    rawset(t, k, re.compile(v, t))
  end,
})

defs.optional = [[
  optional <- {| {:type: '?' -> 'nil' :} |}
]]

defs.description = [[
  description <- %p? %s* {:description: .+ :}
]]


defs.type = [=[
  type <- {| {:type: bracket_literal / value_literal :} |}

  value_literal <- numeric_literal / string_literal
  string_literal <- [^ ~!@#$%^&(){}<>/\;:,?|]+
  numeric_literal <- '-'? [0-9]+

  bracket_literal <- {~ table_literal / array_literal / tuple_literal / fun_literal ~}
  table_literal <- '{' (bracket_literal / [^}])* '}'
  array_literal <- '[' (bracket_literal / [^]])* ']'
  tuple_literal <- string_literal %s* '<' ( [^>])* '>'
  fun_literal   <- 'fun' %s* '(' (bracket_literal / [^)])* ')'
]=] --[[@alias type_ast {type: string}]]

defs.types = [[
  types <- %s* %type %s* (%optional / ('|' types))?
]]

defs.types_capture = [[
  types_capture <- {| %types |}
]] --[[@alias types_ast type_ast[] ]]


defs.name = [[
  name <- ('_' / [^%p%s%d]) ([^%p%s] / [_])*
]]

defs.var = [[
  var <- %s* %name (%s* '.' %s* var)? %s*
]]

defs.ret = [[
  ret <- {| %types %s* ret_name? |}
  ret_name <- {:name: %var :}
]] --[[@alias return_ast {name?: string, [integer]: type_ast}]]

defs.returns = [[
  returns <- {|
    %ret (%s* ',' %s* %ret)*
    %description?
  |}
]] --[[@alias returns_ast {[integer]: return_ast, description?: string}]]

-- multiple assignments not supported
defs.assignment = [[
  assignment <- {| local_assignment / global_assignment |}
  local_assignment <- %s* 'local' %s* {:var: %name :} %s* ('=' %s* {:expr: .+ :})?
  global_assignment <- %s* {:var: %name :} %s* '=' %s* {:expr: .+ :}
]]

-- TODO:
defs.functions = [[
  capture <- {| function / method |}
  function <- 'function' %s* ({:class: %name :} '.')? {:name: %name :} {:args: {| args |} :} [^'end']* 'end'
  method <- 'function' %s* ({:class: %name :} ':')? {:name: %name :} {:args: {| args |} :} [^'end']* 'end'

  args <- %s* '(' %s* ({ %name } (%s* ',' %s* { %name })*)? %s* ')' %s*
]]

return defs
