import open from io

-- get the code as a string
file = open "test.forth", "r"
program = file\read "*a"

-- sigil helper function
alphanumeric = (c) -> if c\match("%w") then true else false 

-- data stack
data_stack = {}
stack_index = 0
push = (v) ->
	stack_index += 1
	data_stack[stack_index] = v
pop = ->
	if stack_index == 0 then 
		error "ERROR POPPING!"
		return
	stack_index -= 1
	data_stack[stack_index+1]

-- dictionary
-- maps word names to a definition
-- a definition is an object with a type field and body field
-- the type tells you if the code is lua code or forth code
-- lua code is a string to be evaluated
-- forth code is a list of words to be evaluated
dictionary = {}

dictionary["one"] = {
	type: "lua"
	body: "push(1)"
}

dictionary["print"] = {
	type: "lua"
	body: "print(pop())"
}

-- definitions recursively call eval so here it is
local eval

-- parsing
-- currently just makes a list of words
parsed = [word for word in string.gmatch program, "([^%s]+)"]
current_word = 0

get_word = ->
	current_word += 1
	parsed[current_word]

-- evaluation of lua and forth code
eval_lua = (body) ->
	f = loadstring body
	if not f then
		error "INVALID LUA DEFINITION"
	env = _G
	env.push = push
	env.pop = pop
	env.get_word = get_word
	env.dictionary = dictionary
	setfenv f, env
	f!

eval_forth = (body) -> 
	for word in *body
		eval word

eval = (name) -> 
	type = dictionary[name].type
	body = dictionary[name].body
	if type == "lua" then
		eval_lua body
	else if type == "forth" then
		eval_forth body
	else
		error "EVAL TYPE ERROR"

dictionary[":"] = {
	type: "lua"
	body: '
		local name
		name = get_word()
		local body
		body = {}
		local length
		length = 0
		while true do
			local word
			word = get_word()
			if word == ";" then
				-- finish definition
				dictionary[name] = {
					type="forth",
					body=body
				}
				break
			else
				-- add word to definition
				-- TODO - immediate words
				length = length + 1
				body[length] = word
			end
		end
	'
}



-- REPL
while true do
	word = get_word!
	if not word then
		break
	eval word

