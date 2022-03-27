#!/bin/bash t/runtest
-- vim: set ft=lua :

local tap = require 'dr.tap'

tap.isnil(nil, 'is nil ok')
tap.isnil({a = 'b'}, 'is nil not ok')

tap.isntnil(nil, 'isnt nil not ok')
tap.isntnil({a = 'b'}, 'isnt nil ok')
