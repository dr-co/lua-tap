#!/bin/bash t/runtest
-- vim: set ft=lua :

local tap = require 'dr.tap'

tap.plan(2)

tap.unlike('123', '%d')
tap.like('abc', '%w-1')

