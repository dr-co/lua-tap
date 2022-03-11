#!/bin/bash t/runtest
-- vim: set ft=lua :

local tap = require 'dr.tap'

local tests = {
    {
        v = 123,
        d = '123',
    },
    {
        v = nil,
        d = 'nil',
    },
    {
        v = 1.23,
        d = '1.23',
    },
    {
        v = 'hello',
        d = '"hello"',
    },
    {
        v = {},
        d = '{}',
        desc = 'empty table'
    },
    {
        v = {1, 2, 3},
        d = '{1, 2, 3}',
        desc = 'array of numbers'
    },
    {
        v = {1, '2', 3},
        d = '{1, "2", 3}',
        desc = 'array of string and numbers'
    },
    {
        v = {123, hello='world'},
        d = '{[1] = 123, hello = "world"}',
        desc = 'mix table'
    },
    
    {
        v = {['12ab'] = {1, 2, 3}},
        d = '{["12ab"] = {1, 2, 3}}',
        desc = 'mix table nokw keys'
    },

    {
        v = string.char(1) .. string.char(2),
        d = '"\\x01\\x02"',
        desc = 'dump \\x01\\x02',
    },
}

tap.plan(#tests)

for _, t in pairs(tests) do
    tap.is(
        tap.dump(t.v),
        t.d,
        t.desc or string.format('dump <%s>: %s', type(t.v), tostring(t.v))
    )
end
