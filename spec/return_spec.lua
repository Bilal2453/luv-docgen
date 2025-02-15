local parseReturn = require('parser').parseReturn

assert = require('luassert')

-- single return
do
  assert.same(parseReturn('string? error_msg'), {
    {
      types = {
        'string',
        'nil',
      },
      name = 'error_msg',
      nilable = true,
    }
  })
  assert.same(parseReturn('{[string]: integer?}?'), {
    {
      types = {
        '{[string]: integer?}',
        'nil',
      },
      name = '',
      nilable = true,
    }
  })
  assert.same(parseReturn('string | number error_msg'), {
    {
      types = {
        'string',
        'number',
      },
      name = 'error_msg',
      nilable = false,
    }
  })
  assert.same(parseReturn('long-alias.less_important'), {
    {
      types = {
        'long-alias.less_important',
      },
      name = '',
      nilable = false,
    }
  })
end

-- multi-returns
do
  -- 0|nil success, string? err_name, string? err_msg
  assert.same(parseReturn('0|nil success, string? err_name, string? err_msg'), {
    {
      types = {
        '0',
        'nil',
      },
      name = 'success',
      nilable = true,
    },
    {
      types = {
        'string',
        'nil',
      },
      name = 'err_name',
      nilable = true,
    },
    {
      types = {
        'string',
        'nil',
      },
      name = 'err_msg',
      nilable = true,
    }
  })
  -- string? no, boolean error
  assert.same(parseReturn('string? no, boolean error'), {
    {
      types = {
        'string',
        'nil',
      },
      name = 'no',
      nilable = true,
    },
    {
      types = {
        'boolean',
      },
      name = 'error',
      nilable = false,
    }
  })
  -- t1 name, t2 | t3 name2
  assert.same(parseReturn('t1 name, t2 | t3 name2'), {
    {
      types = {
        't1',
      },
      name = 'name',
      nilable = false,
    },
    {
      types = {
        't2',
        't3',
      },
      name = 'name2',
      nilable = false,
    }
  })
  -- t1 name, t2, t3 name2, t4? # some description
  assert.same(parseReturn('t1 name, t2, t3 name2, t4? # some description'), {
    {
      types = {
        't1',
      },
      name = 'name',
      nilable = false,
    },
    {
      types = {
        't2',
      },
      name = '',
      nilable = false,
    },
    {
      types = {
        't3',
      },
      name = 'name2',
      nilable = false,
    },
    {
      types = {
        't4',
        'nil',
      },
      name = '',
      nilable = true,
    },
    description = 'some description',
  })
  -- table<a, b> tuple, {complex: true} complex, boolean simple
  assert.same(parseReturn('table<a, b> tuple, {complex: true} complex, boolean simple this is description'), {
    {
      types = {
        'table<a, b>',
      },
      name = 'tuple',
      nilable = false,
    },
    {
      types = {
        '{complex: true}',
      },
      name = 'complex',
      nilable = false,
    },
    {
      types = {
        'boolean',
      },
      name = 'simple',
      nilable = false,
    },
    description = 'this is description',
  })
end
os.exit(0)
