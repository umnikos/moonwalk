import open from io

-- get the code as a string
read_file = (name) ->
	file = open name, "r"
	file\read "*a"
write_file = (name, contents) ->
	file = open name, "w"
	file\write contents

-- serialization and deserialization
-- TODO
serialize = (obj) ->
deserialize = (str) ->

-- sigil helper function
alphanumeric = (c) -> if c\match("%w") then true else false 
entirely_whitespace = (s) -> if s\match("[^%s]") then false else true

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

-- definitions recursively call eval so here it is
local eval

-- parsing
-- currently just makes a list of words
parse = (s) ->
	program = s\gsub("([^%S ]+)"," %1 ")
	[word for word in string.gmatch program, "([^ ]+)"]
parsed = parse read_file "test.forth"
current_word = 0

get_word = ->
	current_word += 1
	-- TODO: error handling in the callers, not the callee
	-- if not parsed[current_word] then
	--	 error "RAN OUT OF WORDS"
	parsed[current_word]

unget_word = (word) ->
	parsed[current_word] = word
	current_word -= 1

-- user-defined lua functions, not to be called from forth but from lua
restore_env = (old_env) ->
	user_env = {}
	setmetatable user_env, {__index: _G}
	for k,v in pairs(old_env)
		user_env[k] = loadstring v
		setfenv user_env[k], user_env
	-- due to setfenv issues these have to be redefined
	-- which means users can't overwrite them sadly
	user_env.push = push
	user_env.pop = pop
	user_env.get_word = get_word
	user_env.unget_word = unget_word
	user_env.dictionary = dictionary
	user_env
user_env = restore_env {}

-- evaluation of lua and forth code
eval_lua = (body) ->
	f = loadstring body
	if not f then
		error "INVALID LUA DEFINITION"
	setfenv f, user_env
	f!

eval_forth = (body) -> 
	for word in *body[(table.getn body),1,-1]
		unget_word word

eval = (name) -> 
	if not dictionary[name] then
		error "UNDEFINED WORD: "..name
	type = dictionary[name].type
	body = dictionary[name].body
	if type == "lua" then
		eval_lua body
	else if type == "forth" then
		eval_forth body
	else
		error "EVAL TYPE ERROR: "..name

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
				length = length + 1
				body[length] = word
			end
		end
	'
}

dictionary["::"] = {
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
			if word == ";;" then
				-- finish definition
				dictionary[name] = {
					type="lua",
					body=table.concat(body, " ")
				}
				break
			else
				-- add word to definition
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
	if entirely_whitespace word then
		pass
	else
		eval word
	-- store environment
	stored_env = {}
	for k,v in pairs(user_env) 
		if "function" == type v
			stored_env[k] = string.dump v
	user_env = restore_env stored_env

-- TODO: make debugging programs easier.

-- TODO: FIGURE OUT HOW TO SERIALIZE FUNCTIONS IN THE USER ENVIRONMENT
