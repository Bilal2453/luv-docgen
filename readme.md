# The Project

This is a docgen that uses the LuaLS Lua comments annotations
to generate machine-readable documentation for the Luv library.

The reason I am using the annotations to generate this instead of parsing the markdown has to do with multiple reasons, but a main one is the completeness this provides.  If we parse the markdown into a Lua table, that would at most be useful to regenerate the markdown docs and stop at that, it would be *very* challenging to convert it into something usable in a language server and even then it would be a sub-optimal experience.
On the other hand, this should be able to both fulfill the needs for regenerating the markdown docs and to use it in a Language server and possibly other applications as well.

There is a chance for this to be used only once for bootstrapping a machine-readable format, and from there maintaining a generator that can regenerate the markdown docs and the annotations as needed.

This is a very rough roadmap and implementation just to get things going, get opinions, etc. Feel free to open issues for communication or contact me on the official [Luvit Discord server](https://discord.gg/luvit), @bilalzero.

## Potential Problems

Currently I am working on the parser, and I can see potential issues coming up.

A) What do we do with the overloads when generating? Merge them into one function? Assume overloads don't exists, they aren't used, how do we represent complicated parameter situations? Like for example `uv.fs_symlink(path, new_path, [flags], [callback])` where the `flags` parameters can be completely omitted and would be treated as the callback `uv.fs_symlink(path, new_path, callback)`.  A potential solution in this scenario would be to have an `omitable` field in the `flags` parameter, but what if there was something even more complicated, like a parameter that could be omitted only if a specific parameter is not provided or is of a specific value.

I feel like this is something a proper parameter annotation can solve, for example when you have a function where no arguments are omitable it would be annotated like `uv.foo(a1, [a1, [, a3]])`, this implies that in order to use `a3` you must pass something to `a1` while `uv.foo(a1, [a2], [a3])` would imply that `a2` is omitable and in order to provide `a3` you can simply do `uv.foo("a1", "a3")`. But it still isn't clear how to structure this, nor is this the format the markdown luv docs follow making detecting when a parameter is omitable ambiguous.

B) How do we represent the sync/async functions? More specifically, how do we express that passing the callback would have different returns than if the callback wasn't passed?


## Roadmap

There are 4 stages that needs to be done:

[x] Tokenization.

[ ] Parsing.

[ ] Preprocessing.

[ ] Generating.

### Tokenization

In this stage, we tokenize the annotations string into a Lua array containing what's called chunks which will be later used by the parser.

The output of this process is an array that contains string arrays, each sub-array represent a "chunk", or a section of the annotations.

A chunk of annotations is any number of Lua comments that all of which starts with 3 dashes `---` and has only one line ending seperating the comment lines, followed by any number of Lua code lines, often function definitions and assignments.
The chunk is terminated on the first occurrence of `\n\n` or on the occurrence of the next chunk which start at the next three dashes comment `---`.

For example the following block has two chunks
```lua
---This is a magical description of a
---secret function in the first chunk!
---@param foo string
function magic1(foo) end
object.magicalMethod = magic1

another_assignment = true -- This is NOT part of the previous chunk because it is seperated by two line endings

---This is the 2nd chunk!
---This chunk has two lines only. The minimum lines a chunk can have is 1.

-- this is not a chunk because it doesn't begin with three dashes ---
function ignored() end
```

You can probably tell what a chunk is by simply looking at the `uv` annotations, but here is an explicit definition.

> A line ending character MUST be `\n`.
>
> Lines arranging a single chunk MUST NOT be seperated
> by more than one line ending.
>
> Different chunks MUST be seperated by two or more line endings.
>
> There MUST exists a trailing `\n` character (line ending) at the end of the string
> of the annotations (at the end the meta annotation file).
>
> The order in which the chunks are defined is always preserved
> and therefor does matter.

See tokenizer.lua for the LPeg grammar and more details.

### Parsing

Using the tokenized chunks to generate something that represent
the docs layout much more closely. This is an intermidate form
that doesn't necessarily represent the final generated structure.

To make the parser, we need to understand what does the luv docs consists of,
what are the main sections/parts and what are those composed of.

The luv docs are composed out of sections, there are 4 (technically 3) types
of those sections: 

- "Text Section": Contains text only chunks, this is mainly the introduction
of luv and the map of content at the very beginning.

- "Class Sections": This is most of the docs, a section for each class
luv has to offer, consists of 3 main sub-sections:
  - A list of classes it inherits from. 
  - A descrption.
  - A list of the methods, along with their params, returns and notes.

- "Functions Section": A group of functions that don't belong to any specific
class but are related. Such as the "Event loop" and "Miscellaneous utils" sections. Consists of 3-4 sub-sections:
  - Description.
  - Params.
  - Returns.
  - Notes. (Optional)

- "Constants Section": Defines any other value under the main `uv` namespace
that isn't a function, such as the `uv.constants` and `uv.errno` tables.

I said that technically there are 3 types not 4, because currently the constants
are under the "Module Layout", I want to change this upstream: put all constants under one section. There are only two constant values, `constants` and `errno` which are tables.

Currently I am thinking of the following format: an array of
tables, each table entry represents a section that has one of the previous types,
the order of this array is identical to the order in which the chunks appear in
the definitions.

See this pseudo table.
Note: replace any `::Type::` with the table defined below this block with the same name.
```lua
{
  {
    type = "text",
    title = "the section title/header",
    description = "...",
    aliases = ::Aliases::, -- it's still possible to have aliases
  },

  {
    type = "class",
    name = "name of class",
    title = "the section title the class is defined within such as (Timer handle)",
    description = "...",
    aliases = ::Aliases::,
    parents = {
      -- an array of the names of classes this
      -- class inherits from. Empty if none.
      "p1", "p2", "etc
    },
    methods = ::Methods:: -- a list of tables representing each method
  },

  {
    type = "functions",
    title = "the section title",
    description = "...",
    aliases = ::Aliases::,
    methods = ::Methods::,
    source = nil or "where in the C code is this section defined?",
  },

  {
    type = "constants",
    title = "the section title",
    description = "...",
    constants = {
      -- an array of tables, each table represent
      -- a constant value, for example a table to represent `uv.errno`.
      {
        name = "errno",
        type = "table", -- I think we should only support tables
        value = "TODO: should this be a string value that holds a table representation or an actual table?",
      }
    }
  },
  
  ...
}
```

Individual types:

```lua
::Aliases::
-- an array of tables that represent an alias
{
  {
    name = "the name of the alias",
    value = "A string of the alias",
    -- TODO: do we want a "types" field that holds an array of alias types?
  },

  ...
}

::Methods::
-- an array of tables that represent a method/function
-- if the function has overloads, the first defined
-- function is considered the main one and the rest
-- of overloads are defined in an overloads field.
-- the methods don't have their class name defined here,
-- if a method is part of another class get the class name
-- from the "class" table.
{
  {
    name = "the name of the function, without uv., without the class name if any",
    description = "...",
    params = {
      -- an array of tables that represent parameters
      -- in the order they are defined in
      {
        name = "the name of the param",
        description = "...",
        type = "TODO: should this be a string of the annotation type or should it be parsed into an array?",
        optional = true or false,
      }
      ...
    },
    returns = {
      -- an array of tables that represent returns
      -- in the order they appear in
      {
        name = "the name of the return or empty string",
        types = "TODO: should this be a string of the annotated returns or should it be parsed into an array?",
        description = "...",
        nilable = true or false, -- TODO: or should this be called "optional"?
      },
      ...
    },
    overloads = {
      -- an array of of tables that represent a function
      -- the structure of those tables are identical to this one (::Method::)
      -- but they won't have an "overloads" field
      ...
    },
  }
}

```

### Preprocessing

In this stage we do whatever needs to be done before the final generating stage.  I am not yet entirely sure what we will do here, possibly might not be even needed, but this is intended to deal with this such as the pseudo failure type, possibly the "unfolding" of aliases, etc.

### Generating

Use the parsed and preprocessed structure to output the final machine-readable docs.  I am assuming not much needs to be done here either, most things should be already handled by the parser.  Potentially this could also be the step at which we output the markdown or whatever else.
