local os = require 'os'
local bit = require 'bit'

local _M = {
    _total = 0,
    _failed = 0,
    _passed = 0,
    _level = -1,
    _plan = -1,
}

local _Mt = {
}

setmetatable(_M, {__index = _Mt})


function _Mt:dump(value)
    if value == nil then
        return 'nil'
    end
    if type(value) == 'number' then
        return tostring(value)
    end

    if type(value) ~= 'table' then
        return string.format('"%s"',
            tostring(value)
                :gsub('\\', '\\\\')
                :gsub('"', '\\"')
        )
    end

    local s = '{'
    local comma = false

    for k, v in pairs(value) do
        if comma then
            s = s .. ', '
        end
        if type(k) ~= 'number' then
            k = self:dump(k)
        end
        s = s .. string.format(
            '[%s] = %s',
            k,
            self:dump(v)
        )
        comma = true
    end
    return s .. '} '
end

function _Mt:_new(desc)
    if desc == nil then
        desc = 'New subtest'
        if self._level < 0 then
            desc = self._desc
        end
    end
    return setmetatable(
        {
            _total = 0,
            _failed = 0,
            _passed = 0,
            _plan = -1,
            _level = self._level + 1,
            _desc = desc,
            _is_dr_tap = true,
        },
        getmetatable(self)
    )
end

function _Mt:test(cb, desc)

    local this = self:_new(desc)

    if this._level >= 0 and desc ~= nil then
        this:note(this._desc)
        this._desc_printed = true
    end

    local status, res = xpcall(
        function() cb(this) end,
        debug.traceback
    )

    if not status then
        this:failed('Exception check')
        this:diag(tostring(res))
    end

    local failed = false
    if this._plan >= 0 then
        if this._total ~= this._plan then
            this:_printf(
                '# Looks like you planned %d tests but run %d',
                this._plan,
                this._total)
            failed = true
        end
    end
    if this._failed > 0 then
        this:_printf(
            '# Looks like you failed %d tests of %d',
            this._failed,
            this._total
        )
        failed = true
    end

    if this._plan < 0 then
        if this._level > 0 and desc ~= nil then
            this:diag(this._desc)
        end
        this:_printf('1..%d', this._total)
    end

    if self._level >= 0 then
        if status and not failed then
            self:passed(this._desc)
        else
            self:failed(this._desc)
        end
    else
        if status and not failed then
            self._total = self._total + 1
            self._passed = self._passed + 1
        else
            self._total = self._total + 1
            self._failed = self._failed + 1
        end
    end

    return status
end

function _Mt:_concat(sep, lst)
    local res = ''

    for i, v in pairs(lst) do
        if i > 1 then
            res = res .. sep
        end
        if i == 1 and (type(v) == 'number' or type(v) == 'string') then
            res = res .. tostring(v)
        else
            res = res .. self:dump(v)
        end
    end
    return res
end

function _Mt:diag(...)
    return self:note(...)
end

function _Mt:note(...)
    local msg = string.gsub(self:_concat('\t', {...}), '\n', '\n# ')
    self:_printf('# %s', msg)
end

function _Mt:_printf(fmt, ...)
    local level = self._level
    if level < 0 then
        level = 0
    end
    local prefix = string.format(
        string.format('%%%ds', level * 2),
        ''
    )
    local message = string.format(fmt, ...)
    print(prefix .. string.gsub(message, '\n', '\n' .. prefix))
end

function _Mt:passed(desc)
    if not desc then
        desc = 'Passed test'
    end
    self._total = self._total + 1
    self._passed = self._passed + 1

    self:_printf('ok %d - %s', self._total, desc)

    return true
end

function _Mt:failed(desc)
    if not desc then
        desc = 'Failed test'
    end

    self._total = self._total + 1
    self._failed = self._failed + 1

    self:_printf('not ok %d - %s', self._total, desc)

    return false
end


function _Mt:_make_caller()
    local res = debug.getinfo(3)
    return res.short_src .. ':' .. tostring(res.currentline)
end

function _Mt:ok(cond, desc)
    if desc == nil then
        desc = 'True condition'
    end

    if cond then
        return self:passed(desc)
    end

    self:failed(desc)
    self:diag(self:_make_caller())
    return false
end

function _Mt:is(value, expected, desc)
    if desc == nil then
        desc = 'Expected value test'
    end

    if self:dump(value) == self:dump(expected) then
        return self:passed(desc)
    end
    self:failed(desc)
    self:diag(self:_make_caller())
    self:diag(
        string.format('got value <%s>: %s', type(value), self:dump(value))
    )
    self:diag(
        string.format(' expected <%s>: %s', type(expected), self:dump(expected))
    )
    return false
end

function _Mt:like(got, pattern, desc)
    if desc == nil then
        desc = 'Check if the string is equivalent to the pattern'
    end

    if string.match(tostring(got), pattern) then
        return self:passed(desc)
    end
    
    self:failed(desc)
    self:diag(self:_make_caller())
    self:diag(
        string.format('got value <%s>: %s', type(got), self:dump(got))
    )
    self:diag(
        string.format('  pattern <%s>: %s', type(pattern), self:dump(pattern))
    )
    return false
end

function _Mt:unlike(got, pattern, desc)
    if desc == nil then
        desc = "Check if the string isn't equivalent to the pattern"
    end

    if not string.match(tostring(got), pattern) then
        return self:passed(desc)
    end
    
    self:failed(desc)
    self:diag(self:_make_caller())
    self:diag(
        string.format('  got value <%s>: %s', type(got), self:dump(got))
    )
    self:diag(
        string.format('antipattern <%s>: %s', type(pattern), self:dump(pattern))
    )
    return false
end

function _Mt:isnt(value, expected, desc)
    if desc == nil then
        desc = 'Unexpected value test'
    end

    if self:dump(value) ~= self:dump(expected) then
        return self:passed(desc)
    end
    self:failed(desc)
    self:diag(self:_make_caller())
    self:diag(
        string.format('got value <%s>: %s', type(value), self:dump(value))
    )
    self:diag(' expected: anything else')
    return false
end

function _Mt:isa(value, type_name, desc)
    if desc == nil then
        desc = 'Check if type(value) is ' .. tostring(type_name)
    end
    
    if type(value) == type_name then
        return self:passed(desc)
    end
    self:failed(desc)
    self:diag(self:_make_caller())
    self:diag(
        string.format('got value <%s>: %s', type(value), self:dump(value))
    )
    self:diag(
        string.format('expected: <%s>', self:dump(type_name))
    )
    return false
end


function _Mt:lt(a, b, desc)
    if desc == nil then
        desc = 'less than test'
    end

    local status, res = pcall(function() return a < b end)
    if status and res then
        return self:passed(desc)
    end
    self:failed(desc)
    self:diag(self:_make_caller())
    self:diag('`a` greater or equal `b`')
    self:diag(string.format(' value a <%s>: %s', type(a), self:dump(a)))
    self:diag(string.format(' value b <%s>: %s', type(b), self:dump(b)))
    return false
end

function _Mt:le(a, b, desc)
    if desc == nil then
        desc = 'less than or equal test'
    end

    local status, res = pcall(function() return a <= b end)
    if status and res then
        return self:passed(desc)
    end
    self:failed(desc)
    self:diag(self:_make_caller())
    self:diag('`a` greater than `b`')
    self:diag(string.format(' value a <%s>: %s', type(a), self:dump(a)))
    self:diag(string.format(' value b <%s>: %s', type(b), self:dump(b)))
    return false
end

function _Mt:gt(a, b, desc)
    if desc == nil then
        desc = 'greater than test'
    end

    local status, res = pcall(function() return a > b end)
    if status and res then
        return self:passed(desc)
    end
    self:failed(desc)
    self:diag(self:_make_caller())
    self:diag('`a` less or equal `b`')
    self:diag(string.format(' value a <%s>: %s', type(a), self:dump(a)))
    self:diag(string.format(' value b <%s>: %s', type(b), self:dump(b)))
    return false
end

function _Mt:ge(a, b, desc)
    if desc == nil then
        desc = 'greater than or equal test'
    end

    local status, res = pcall(function() return a >= b end)
    if status and res then
        return self:passed(desc)
    end
    self:failed(desc)
    self:diag(self:_make_caller())
    self:diag('`a` less than `b`')
    self:diag(string.format(' value a <%s>: %s', type(a), self:dump(a)))
    self:diag(string.format(' value b <%s>: %s', type(b), self:dump(b)))
    return false
end

function _Mt:plan(plan, message)

    assert(plan >= 0)
    if message == nil then
        message = self._desc
    else
        self._desc = message
    end
    if self._total > 0 then
        self:failed('Too late call :plan')
    else
        self._plan = plan
        if not self._desc_printed then
            self:diag(self._desc)
        end
        self:_printf('1..%d', plan)
    end

    return self._plan
end

function _Mt:stat()
    local res = {
        status = 'ok',
        total = self._total,
        failed = self._failed,
        plan = self._plan,
    }

    if self._failed > 0 then
        res.status = 'failed'
    end

    if self._plan >= 0 and self._plan ~= self._total then
        res.status = 'failed'
    end
    return res
end



-- local tap = _M:_new(debug.getinfo(3).short_src)
-- tap._level = -1


local tap = {
    _registered = {},
    _is_dr_tap = true,
}

function tap.test(self, cb, desc)

    if type(self) == 'function' then
        desc = cb
        cb = self
        self = tap
    end


    table.insert(
        self._registered,
        {
            cb = cb,
            desc = desc,
        }
    )
end

local t = _M:_new(debug.getinfo(3).short_src)

function tap:_run()

    local code = 0

    if #self._registered == 0 then
        print('0..0 # no tests run')
    elseif #self._registered == 1 then
        t._level = -1
    elseif #self._registered > 1 then
        t:plan(#self._registered)
        t._level = 0
    end

    for _, tst in pairs(self._registered) do
        t:test(tst.cb, tst.desc)
    end

    if #self._registered > 0 then
        if t:stat().status ~= 'ok' then
            code = 1
        end
    end

    os.exit(code)
end


getmetatable(newproxy(true)).__gc = function()
    tap:_run()
end

return tap
