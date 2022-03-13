#!/bin/bash t/runtest
-- vim: set ft=lua :

local tap = require 'dr.tap'

tap.plan(2, 'require_ok')

tap.require_ok('dr.tap1', 'normal error')
tap.require_ok('dr.tap1', 'full stack error', true)
