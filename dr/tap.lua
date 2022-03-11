local os = require 'os'
local bit = require 'bit'


local tap_default = {
    _level = -1,
    _total = 0,
    _failed = 0,
    _passed = 0,
    _plan = -1,
    _desc = '',
    _is_dr_tap = true,
    _desc_printed = false,
}

local function table_copy(t, e)
    local res = {}

    for k, v in pairs(t) do
        if type(v) == 'table' then
            res[k] = table_copy(v)
        else
            res[k] = v
        end
    end

    if e ~= nil then
        for k, v in pairs(e) do
            if type(v) == 'table' then
                res[k] = table_copy(v)
            else
                res[k] = v
            end
        end
    end

    return res
end

local tap = table_copy(tap_default)
local methods = {}
local checks = {}

setmetatable(
    tap,
    {
        __libm = methods,
        __libc = checks,
        __index = function(self, name)
            local mt = getmetatable(self)
            local is_check = false
            local cb = mt.__libm[name]

            if cb == nil then
                is_check = true
                cb = mt.__libc[name]
            end

            if cb == nil then
                error('unknown TAP attribute: ' .. name)
            end

            return function(arg1, ...)

                local args

                if arg1 == self then
                    args = {self, ...}
                else
                    args = {self, arg1, ...}
                end

                return cb(unpack(args))
            end
        end
    }
)


function methods.dump(self, value, quote_key)
    if value == nil then
        return 'nil'
    end
    if type(value) == 'number' then
        if quote_key then
            return string.format('[%s]', tostring(value))
        end
        return tostring(value)
    end

    if type(value) ~= 'table' then
        value = tostring(value)

        if quote_key then
            if value:match('^%a%w*$') ~= nil then
                return value
            else
                return string.format('[%s]', self.dump(value))
            end
        end
        return string.format('"%s"',
                value
                    :gsub('\\', '\\\\')
                    :gsub('"', '\\"')
        )
    end


    local tlen = #value
    local tlen_c = 0
    local index = 0

    for k, v in pairs(value) do
        index = index + 1
        if type(k) ~= 'number' or index ~= k then
            tlen_c = tlen + 1
            break
        end
        tlen_c = tlen_c + 1
    end

    local s, comma = '{', false
    
    if tlen_c == tlen then
        for k, v in pairs(value) do
            if comma then
                s = s .. ', '
            end
            comma = true
            s = s .. self.dump(v)
        end
        s = s .. '}'
        return s
    end

    for k, v in pairs(value) do
        if comma then
            s = s .. ', '
        end
        s = s .. string.format(
            '%s = %s',
            self.dump(k, true),
            self.dump(v)
        )
        comma = true
    end
    return s .. '}'
end

function methods._new(self, desc)
    if desc == nil then
        desc = 'New subtest'
        if self._level < 0 then
            desc = self._desc
        end
    end

    return setmetatable(
        table_copy(
            tap_default,
            {
                _level = self._level + 1,
                _desc = desc,
            }
        ),
        getmetatable(self)
    )
end

function methods._make_footer(self)
    local failed = false
    if self._plan >= 0 then
        if self._total ~= self._plan then
            self._printf(
                '# Looks like you planned %d tests but run %d',
                self._plan,
                self._total)
            failed = true
        end
    end
    if self._failed > 0 then
        self._printf(
            '# Looks like you failed %d tests of %d',
            self._failed,
            self._total
        )
        failed = true
    end
    if self._plan < 0 then
        if self._level > 0 and desc ~= nil then
            self.diag(self._desc)
        end
        self._printf('1..%d', self._total)
    end

    return failed
end

function checks.test(self, cb, desc)

    local this = self._new(desc)

    if this._level >= 0 and desc ~= nil then
        this.note(this._desc)
        this._desc_printed = true
    end

    local status, res = xpcall(
        function() cb(this) end,
        debug.traceback
    )

    if not status then
        this.failed('Exception check')
        this.diag(tostring(res))
    end

    local failed = this._make_footer()

    if self._level >= 0 then
        if status and not failed then
            self.passed(this._desc)
        else
            self.failed(this._desc)
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

function methods._concat(self, sep, lst)
    local res = ''

    for i, v in pairs(lst) do
        if i > 1 then
            res = res .. sep
        end
        if i == 1 and (type(v) == 'number' or type(v) == 'string') then
            res = res .. tostring(v)
        else
            res = res .. self.dump(v)
        end
    end
    return res
end

function methods.diag(self, ...)
    return self.note(...)
end

function methods.note(self, ...)
    local msg = string.gsub(self._concat('\t', {...}), '\n', '\n# ')
    self._printf('# %s', msg)
end

function methods._printf(self, fmt, ...)
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

function checks.passed(self, desc)
    if not desc then
        desc = 'Passed test'
    end
    self._total = self._total + 1
    self._passed = self._passed + 1

    self._printf('ok %d - %s', self._total, desc)

    return true
end

function checks.failed(self, desc)
    if not desc then
        desc = 'Failed test'
    end

    self._total = self._total + 1
    self._failed = self._failed + 1

    self._printf('not ok %d - %s', self._total, desc)

    return false
end


function methods._make_caller(self)
    local res = debug.getinfo(3)
    if res == nil then
        return 'unknown.lua:<unknown-line>'
    end
    return res.short_src .. ':' .. tostring(res.currentline)
end

function checks.ok(self, cond, desc)
    if desc == nil then
        desc = 'True condition'
    end

    if cond then
        return self.passed(desc)
    end

    self.failed(desc)
    self.diag(self._make_caller())
    return false
end

function checks.is(self, value, expected, desc)
    if desc == nil then
        desc = 'Expected value test'
    end

    if self.dump(value) == self.dump(expected) then
        return self.passed(desc)
    end
    self.failed(desc)
    self.diag(self._make_caller())
    self.diag(
        string.format('got value <%s>: %s', type(value), self.dump(value))
    )
    self.diag(
        string.format(' expected <%s>: %s', type(expected), self.dump(expected))
    )
    return false
end

function checks.like(self, got, pattern, desc)
    if desc == nil then
        desc = 'Check if the string is equivalent to the pattern'
    end

    local pos = string.find(tostring(got), tostring(pattern))

    if pos  ~= nil then
        return self.passed(desc)
    end

    self.failed(desc)
    self.diag(self._make_caller())
    self.diag(
        string.format('got value <%s>: %s', type(got), self.dump(got))
    )
    self.diag(
        string.format('  pattern <%s>: %s', type(pattern), self.dump(pattern))
    )
    return false
end

function checks.unlike(self, got, pattern, desc)
    if desc == nil then
        desc = "Check if the string isn't equivalent to the pattern"
    end

    local pos = string.find(tostring(got), tostring(pattern))

    if pos  == nil then
        return self.passed(desc)
    end

    self.failed(desc)
    self.diag(self._make_caller())
    self.diag(
        string.format('  got value <%s>: %s', type(got), self.dump(got))
    )
    self.diag(
        string.format('antipattern <%s>: %s', type(pattern), self.dump(pattern))
    )
    return false
end

function checks.isnt(self, value, expected, desc)
    if desc == nil then
        desc = 'Unexpected value test'
    end

    if self.dump(value) ~= self.dump(expected) then
        return self.passed(desc)
    end
    self.failed(desc)
    self.diag(self._make_caller())
    self.diag(
        string.format('got value <%s>: %s', type(value), self.dump(value))
    )
    self.diag(' expected: anything else')
    return false
end

function checks.isa(self, value, type_name, desc)
    if desc == nil then
        desc = 'Check if type(value) is ' .. tostring(type_name)
    end

    if type(value) == type_name then
        return self.passed(desc)
    end
    self.failed(desc)
    self.diag(self._make_caller())
    self.diag(
        string.format('got value <%s>: %s', type(value), self.dump(value))
    )
    self.diag(
        string.format('expected: <%s>', self.dump(type_name))
    )
    return false
end


function checks.lt(self, a, b, desc)
    if desc == nil then
        desc = 'less than test'
    end

    local status, res = pcall(function() return a < b end)
    if status and res then
        return self.passed(desc)
    end
    self.failed(desc)
    self.diag(self._make_caller())
    self.diag('`a` greater than or equal `b`')
    self.diag(string.format(' value a <%s>: %s', type(a), self.dump(a)))
    self.diag(string.format(' value b <%s>: %s', type(b), self.dump(b)))
    return false
end

function checks.le(self, a, b, desc)
    if desc == nil then
        desc = 'less than or equal test'
    end

    local status, res = pcall(function() return a <= b end)
    if status and res then
        return self.passed(desc)
    end
    self.failed(desc)
    self.diag(self._make_caller())
    self.diag('`a` greater than `b`')
    self.diag(string.format(' value a <%s>: %s', type(a), self.dump(a)))
    self.diag(string.format(' value b <%s>: %s', type(b), self.dump(b)))
    return false
end

function checks.gt(self, a, b, desc)
    if desc == nil then
        desc = 'greater than test'
    end

    local status, res = pcall(function() return a > b end)
    if status and res then
        return self.passed(desc)
    end
    self.failed(desc)
    self.diag(self._make_caller())
    self.diag('`a` less than or equal `b`')
    self.diag(string.format(' value a <%s>: %s', type(a), self.dump(a)))
    self.diag(string.format(' value b <%s>: %s', type(b), self.dump(b)))
    return false
end

function checks.ge(self, a, b, desc)
    if desc == nil then
        desc = 'greater than or equal test'
    end

    local status, res = pcall(function() return a >= b end)
    if status and res then
        return self.passed(desc)
    end
    self.failed(desc)
    self.diag(self._make_caller())
    self.diag('`a` less than `b`')
    self.diag(string.format(' value a <%s>: %s', type(a), self.dump(a)))
    self.diag(string.format(' value b <%s>: %s', type(b), self.dump(b)))
    return false
end

function methods.plan(self, plan, message)

    assert(plan >= 0)
    if message == nil then
        message = self._desc
    else
        self._desc = message
    end
    if self._total > 0 then
        self.failed('Too late call :plan')
    else
        self._plan = plan
        if not self._desc_printed then
            self.diag(self._desc)
        end
        self._printf('1..%d', plan)
    end

    return self._plan
end

function methods.stat(self)
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

function methods._done(self, code, exitf)

    local stat = self.stat()

    local failed = self._make_footer()

    io.flush()

    if failed then
        exitf(1)
    end

    exitf(code)
end

local function process_exit(tap)
    local exitf = os.exit

    _G._tap_gc_for_onexit = newproxy(true)
    getmetatable(_G._tap_gc_for_onexit).__gc = function()
        tap._done(0, exitf)
    end


    -- tarantool
    if package.loaded.box ~= nil and package.loaded.box.ctl ~= nil then
        local ffi = require 'ffi'
        ffi.cdef[[
            void _exit(int status);
        ]]
        exitf = function(code)
            ffi.C._exit(code)
        end

        box.ctl.on_shutdown(
            function()
                tap._done(0, exitf)
            end
        )
    end

    function os.exit(code)
        tap._done(code, exitf)
    end
end

local t = tap._new(debug.getinfo(3).short_src)
process_exit(t)
return t

