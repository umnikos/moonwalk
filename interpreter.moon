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
delete_file = (name) ->
	os.remove name

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
			s = s.."["..serialize(k).."] = "..(serialize v)..", "
		return s.." }"
	else if "function" == type o
		-- this is how you'd get the environment
		-- if it was possible to serialize it
		-- but the environment contains functions so it's not
		--d = debug.getinfo o
		--env = d.func
		str = string.dump o
		return "(function(env)\n local f = loadstring("..serialize(str)..")\n setfenv(f,env)\n return f".."\n end)(env)"
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
-- the type tells you if the code is lua code or moonwalk code
-- lua code is a string to be evaluated
-- moonwalk code is a list of words to be evaluated
--dictionary = {}
local dictionary

-- definitions recursively call eval so here it is
local eval

-- parsing
-- currently just makes a list of words
parse = (s) ->
	program = s\gsub("([^%S ]+)"," %1 ")
	[word for word in string.gmatch program, "([^ ]+)"]
--parsed = parse read_file "test.mw"
local parsed
current_word = 0

get_word = ->
	current_word += 1
	-- TODO: error handling in the callers, not the callee
	-- if not parsed[current_word] then
	--	 error "RAN OUT OF WORDS"
	parsed[current_word]

should_save = ->
	word = dictionary[parsed[current_word+1]]
	-- nothing to execute, why save before nothing?
	if not word 
		return false
	-- expansion is a pure operation
	if word.type == "moonwalk"
		return false
	-- pure words are also pure
	if word.recovery == "pure"
		return false
	-- if not sure, default to true
	print "FAILED TO SPARE YOU"
	return true

unget_word = (word) ->
	parsed[current_word] = word
	current_word -= 1

-- user-defined lua functions, not to be called from moonwalk but from lua
local user_env
restore_env = (old_env) ->
	user_env = {}
	setmetatable user_env, {__index: _G}
	for k,v in pairs(old_env)
		user_env[k] = v
		if "function" == type user_env[k]
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
restore_task_queue = (old_task_queue, old_current_word) ->
	parsed = old_task_queue
	current_word = old_current_word
restore_stack = (old_stack, old_stack_index) ->
	data_stack = old_stack
	stack_index = old_stack_index
restore_dictionary = (old_dictionary) ->
	dictionary = old_dictionary
save_state = -> 
	current_state = {
		stack: data_stack
		task_queue: parsed
		env: user_env
		dictionary: dictionary
		current_word: current_word
		stack_index: stack_index
	}
	write_file "current_state.state", serialize current_state
store_state = save_state
restore_state = -> 
	str = read_file "current_state.state"
	local old_state
	if str
		--print "OLD STATE GOTTEN"
		old_state = deserialize str, {}
	else
		--print "NEW STATE CREATED"
		old_state = {
			stack: {}
			task_queue: parse read_file "test.mw"
			env: {}
			dictionary: {}
			current_word: 0
			stack_index: 0
		}
	restore_dictionary old_state.dictionary
	restore_stack old_state.stack, old_state.stack_index
	restore_task_queue old_state.task_queue, old_state.current_word
	restore_env old_state.env
delete_state = ->
	delete_file "current_state.state"

restore_state!

-- evaluation of lua and moonwalk code
eval_lua = (body) ->
	f = loadstring body
	if not f then
		error "INVALID LUA DEFINITION"
	setfenv f, user_env
	f!

eval_mw = (body) -> 
	for word in *body[(table.getn body),1,-1]
		unget_word word

eval = (name) -> 
	if not dictionary[name] then
		error "UNDEFINED WORD: "..name
	type = dictionary[name].type
	body = dictionary[name].body
	if type == "lua" then
		eval_lua body
	else if type == "moonwalk" then
		eval_mw body
	else
		error "EVAL TYPE ERROR: "..name

dictionary[":"] = {
	type: "lua"
	recovery: "pure"
	body: '
		local name
		name = get_word()
		--print("DEFINING "..name)
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
					type="moonwalk",
					body=body,
					recovery="pure"
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
	recovery: "pure"
	body: '
		local name
		name = get_word()
		--print("DEFINING "..name)
		local recovery
		recovery = get_word()
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
					body=table.concat(body, " "),
					recovery=recovery
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
	if should_save!
		store_state!
	word = get_word!
	--print word
	if not word then
		break
	if entirely_whitespace word then
		pass
	else
		eval word
delete_state!


-- TODO: make debugging programs easier.
