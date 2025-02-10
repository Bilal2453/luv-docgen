local parseTypes = require('parser').parseTypes

assert = require('luassert')

do
  assert.same(parseTypes('string'), {
    {
      type = 'string'
    },
  })
  assert.same(parseTypes('string | number'), {
    {
      type = 'string'
    },
    {
      type = 'number'
    },
  })
  assert.same(parseTypes('string?'), {
    {
      type = 'string'
    },
    {
      type = 'nil'
    },
  })
  assert.same(parseTypes('string | number?'), {
    {
      type = 'string'
    },
    {
      type = 'number'
    },
    {
      type = 'nil'
    },
  })
  -- TODO: should we do de-duplication or not?
  -- assert.same(parseTypes('string | nil?'), {
  --   {
  --     type = 'string'
  --   },
  --   {
  --     type = 'nil'
  --   },
  -- })
  assert.same(parseTypes('{foo: string | number, bar: fun(a, b)} | integer'), {
    {
      type = '{foo: string | number, bar: fun(a, b)}'
    },
    {
      type = 'integer'
    },
  })
  assert.same(parseTypes('fun(a: string[]) | {foo: string | number, bar: fun(a, b)}?'), {
    {
      type = 'fun(a: string[])'
    },
    {
      type = '{foo: string | number, bar: fun(a, b)}'
    },
    {
      type = 'nil'
    },
  })
end

os.exit(0)
