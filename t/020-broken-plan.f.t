#!/bin/bash t/runtest
-- vim: set ft=lua :

local tap = require 'dr.tap'

tap.plan(2)
tap.passed('passed test')

