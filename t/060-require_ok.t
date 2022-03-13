#!/bin/bash t/runtest
-- vim: set ft=lua :

local tap = require 'dr.tap'

tap.plan(1, 'require_ok')
tap.require_ok('dr.tap')
