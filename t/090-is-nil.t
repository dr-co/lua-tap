#!/bin/bash t/runtest
-- vim: set ft=lua :

local tap = require 'dr.tap'
tap.plan(3)

local a, b = nil, nil

tap.is(a, b, 'a is b and is nil')
tap.isnt(1, b, 'a isnt nil')
tap.isnt(a, 1, 'nil isnt 1')
