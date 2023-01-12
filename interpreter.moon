import open from io

-- get the code as a string
read_file = (name) ->
	file = open name, "r"
	if file
		file\read "*a"
	else
		nil
write_file = (name, contents) ->
	file = open name, "w"
	file\write contents

-- serialization and deserialization
serialize = (o) ->
	if "string" == type o
		s = string.format "%q", o
		--for c in s\gmatch "."
		--	print (string.format "%x", c\byte 1)
		return s
	else if "number" == type o
		return o
	else if "boolean" == type o
		return tostring(o)
	else if "nil" == type o
		return "nil"
	else if "table" == type o
		s = "{ "
		for k,v in pairs(o)
			s = s.."["..k.."] = "..(serialize v)..", "
		return s.." }"
	else if "function" == type o
		d = debug.getinfo o
		env = d.func
		str = string.dump o
		return "(function()\n local f = loadstring("..serialize(str)..")\n setfenv(f,env)\n return f".."\n end)()"
	else
		error "DIDN'T THINK OF TYPE "..(type o).." FOR SERIALIZING"
deserialize = (str,env) ->
	s = "return function(env)\n return "..str.."\n end"
	write_file "test3.lua", s
	f = (loadstring s)!
	return f env

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
--parsed = parse read_file "test.forth"
local parsed
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
local user_env
restore_env = (old_env) ->
	user_env = {}
	setmetatable user_env, {__index: _G}
	for k,v in pairs(old_env)
		user_env[k] = loadstring v
		setfenv user_env[k], user_env
	-- due to setfenv issues these have to be redefined
	-- which means users can't overwrite them sadly
	-- (the issue is upvalues not being preserved)
	user_env.push = push
	user_env.pop = pop
	user_env.get_word = get_word
	user_env.unget_word = unget_word
	user_env.dictionary = dictionary
	user_env
restore_task_queue = (old_task_queue) ->
	parsed = old_task_queue
restore_stack = (old_stack) ->
	stack = old_stack
save_state = -> 
	current_state = {
		stack: stack
		task_queue: parsed
		env: user_env
	}
	write_file "current_state.state", serialize current_state
store_state = save_state
restore_state = -> 
	str = read_file "current_state.state"
	local old_state
	if str
		old_state = deserialize str
	else
		old_state = {
			stack: {}
			task_queue: parse read_file "test.forth"
			env: {}
		}
	restore_stack old_state.stack
	restore_task_queue old_state.task_queue
	restore_env old_state.env
restore_state!

restore_env {}
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
restore_state!
while true do
	word = get_word!
	if not word then
		break
	if entirely_whitespace word then
		pass
	else
		eval word
	store_state!


-- TODO: make debugging programs easier.
