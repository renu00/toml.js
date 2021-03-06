isNumeric = (n) -> not isNaN parseInt(n, 10)

unescape = (str) ->
    str
        .replace('\\n', "\n")
        .replace('\\t', "\t")
        .replace(/\\(["'])/, "$1")

newlines   = "\n\r"
whitespace = "\t "
delimiters = "[].="
quotes     = "\"'"

ignore = [null, 'newline', 'whitespace']
values = ['number', 'string', 'date']

toml = (input) ->

    root = {}
    context = root

    state  = null
    skip   = 0

    accum = ''

    token = null
    key   = null
    value = null
    list  = null
    lists = {}
    nesting = -1

    quote = null
    prev = null

    eat = (char, reg, st) ->
        unless reg.test(char) then state = st; token = accum; accum = ''; yes
        else accum += char; no

    for char, i in input.toString() + "\n"
        continue if --skip > 0

        console.log char, state if toml.debug

        # Ignore idle states, reset `state`
        if state?.slice(-4) is '_end' then state = null

        if not state and char in newlines then state = 'newline'

        # Strip comments
        if state in ignore and char is '#' then state = 'comment'
        if state is 'comment'
            if char not in newlines then continue else state = 'newline'

        # Strip whitespace
        if state in ['whitespace', 'expect_value'] and char in whitespace then continue
        if prev in newlines and char in whitespace then state = 'whitespace'; continue

        # Group
        if state in ignore and char is '[' then state = 'group'; continue
        if state is 'group' and eat(char, /[^\]]/) then group = token

        # Nested groups
        if group
            context = root
            context = context[part] ?= {} for part in group.split '.'
            group = null

        # Keys
        if state in ignore and /\w/.test(char) then state = 'key'
        if state is 'key' and eat(char, /[^=]/) then key = token.trim()

        # Values
        if key and char is '=' then state = 'expect_value'; continue

        if state is 'expect_value'
            # String
            if char in quotes then state = 'string'; quote = char; continue

            # Boolean
            if char is 't' and input[i..i+3] is 'true' then value = true; skip = 4; state = null
            if char is 'f' and input[i..i+4] is 'false' then value = false; skip = 5; state = null

            # Number
            if char is '-' then state = 'number'; accum = '-'; continue
            if isNumeric char then state = 'number'

            # Array
            if char is '[' then list = lists[++nesting] = []; continue

        if state is 'string' and eat(char, /[^"']/, 'string_end') then value = unescape token
        if state is 'number' and eat(char, /[\d.]/, 'number_end') then value = +token
        if state is 'date'   and eat(char, /[\d-:TZ]/)            then value = new Date(token)

        # Escaped quotes
        if state is 'string_end'
            if char isnt quote or (char is quote and prev is '\\') then state = 'string'; accum = value + char; value = null
            else state = null; quote = null

        # Date literal
        if state is 'number_end'
            if char is '-' then state = 'date'; accum = token + char; value = null
            else state = null

        if list? # Capture values
            if value? then list.push(value); value = null; state = 'expect_value'
            if char is ',' then continue
            if char is ']' and state not in values
                if nesting is 0 then value = list; list = null; nesting = -1; state = null
                if nesting > 0 then lists[--nesting].push list; list = lists[nesting]

        if key and value?
            context[key] = value
            key = value = null

        prev = char

    return root

if typeof exports isnt 'undefined'
    module.exports = toml
else 
    @toml = toml
