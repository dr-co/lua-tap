# TAP system for Lua

- [TAP](https://en.wikipedia.org/wiki/Test_Anything_Protocol)

## SYNOPSIS

```lua

local tap = require 'tap'

tap:test(
	function(tap)
		tap:plan(2, 'my tests')
		tap:le(1, 2, '1 < 2')
		tap:is(25, 25, '25 is 25')
	end
end)

```

## Features

- You don't need look after exitcode.

- Lua 5.1 (may be 5.x, I don't know)

## Tests

### tap:passed([description])

### tap:failed([description])

### tap:ok(cond[, description])

### tap:is(value, expected[, description])

### tap:isnt(value, unexpected[, description])

### tap:le(a, b[, description])

### tap:lt(a, b[, description])

### tap:ge(a, b[, description])

### tap:gt(a, b[, description])

### tap:test(function(tap) ... end[, description])

New subtest block.

### tap:note(...)

Print note message (TAP protocol)

### tap:diag(...)

Print diagnostic message (TAP protocol)
