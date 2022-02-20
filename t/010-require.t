#!/usr/bin/lua


local tap = require 'dr.tap'

tap:test(
    function(tap)
        -- tap:plan(3)
        tap:passed('passed test')

        tap:test(
            function(tap)
                tap:plan(1, 'привет')
                tap:passed('subtest')
            end
        )
        
        tap:test(
            function(tap)
                tap:passed('subtest')

                tap:ok(true, 'ok test')
                tap:is(1, 1, 'is test')

                tap:is({1, a = 2}, {1, a = 2}, 'is (table)')
                tap:isnt(1, 2, 'isnt')
                tap:isnt({a = 2}, {a = "2"}, 'isnt (table)')
                tap:ge(11, 11)
                tap:ge(11, 8)
                tap:gt(11, 1)
                tap:le(11, 11)
                tap:le(11, 12)
                tap:lt(11, 12)
            end,
            'named subtest 2'
        )
    end
)
