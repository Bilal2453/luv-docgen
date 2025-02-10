local parseReturn = require('parser').parseReturn

assert = require('luassert')

-- single return
do
  assert.same(parseReturn('string? error_msg'), {
    {
      types = {
        {type = 'string'},
        {type = 'nil'},
      },
      name = 'error_msg',
      nilable = true,
    }
  })
  assert.same(parseReturn('{[string]: integer?}?'), {
    {
      types = {
        {type = '{[string]: integer?}'},
        {type = 'nil'},
      },
      name = '',
      nilable = true,
    }
  })
  assert.same(parseReturn('string | number error_msg'), {
    {
      types = {
        {type = 'string'},
        {type = 'number'},
      },
      name = 'error_msg',
      nilable = false,
    }
  })
  assert.same(parseReturn('long-alias.less_important'), {
    {
      types = {
        {type = 'long-alias.less_important'},
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
        {type = '0'},
        {type = 'nil'},
      },
      name = 'success',
      nilable = true,
    },
    {
      types = {
        {type = 'string'},
        {type = 'nil'},
      },
      name = 'err_name',
      nilable = true,
    },
    {
      types = {
        {type = 'string'},
        {type = 'nil'},
      },
      name = 'err_msg',
      nilable = true,
    }
  })
  -- string? no, boolean error
  assert.same(parseReturn('string? no, boolean error'), {
    {
      types = {
        {type = 'string'},
        {type = 'nil'},
      },
      name = 'no',
      nilable = true,
    },
    {
      types = {
        {type = 'boolean'},
      },
      name = 'error',
      nilable = false,
    }
  })
  -- t1 name, t2 | t3 name2
  assert.same(parseReturn('t1 name, t2 | t3 name2'), {
    {
      types = {
        {type = 't1'},
      },
      name = 'name',
      nilable = false,
    },
    {
      types = {
        {type = 't2'},
        {type = 't3'},
      },
      name = 'name2',
      nilable = false,
    }
  })
  -- t1 name, t2, t3 name2, t4? # some description
  assert.same(parseReturn('t1 name, t2, t3 name2, t4? # some description'), {
    {
      types = {
        {type = 't1'},
      },
      name = 'name',
      nilable = false,
    },
    {
      types = {
        {type = 't2'},
      },
      name = '',
      nilable = false,
    },
    {
      types = {
        {type = 't3'},
      },
      name = 'name2',
      nilable = false,
    },
    {
      types = {
        {type = 't4'},
        {type = 'nil'},
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
        {type = 'table<a, b>'},
      },
      name = 'tuple',
      nilable = false,
    },
    {
      types = {
        {type = '{complex: true}'},
      },
      name = 'complex',
      nilable = false,
    },
    {
      types = {
        {type = 'boolean'},
      },
      name = 'simple',
      nilable = false,
    },
    description = 'this is description',
  })
end
os.exit(0)
