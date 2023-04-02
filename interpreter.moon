import open from io

args = {...}

-- get the code as a string
read_file = (name) ->
	file = open name, "r"
	if file
		contents = file\read "*a"
		file\close!
		contents
	else
		nil
write_file = (name, contents) ->
	file = open name, "w"
	file\write contents
	file\close!
delete_file = (name) ->
	if fs
		fs.delete name
	else
		os.remove name
rename_file = (old, new) ->
	if fs
		if fs.exists new
			fs.delete new
		fs.move old, new
	else
		os.rename old, new

-- serialization and deserialization
serialize = (o) ->
	if "string" == type o
		s = string.format "%q", o
		return s
	else if "number" == type o
		if o == 1/0
			return "(1/0)"
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
		str = string.dump o
		return "(function(env)\n local f = loadstring("..serialize(str)..")\n setfenv(f,env)\n return f".."\n end)(env)"
	else
		error "DIDN'T THINK OF TYPE "..(type o).." FOR SERIALIZING"
deserialize = (str,env) ->
	s = "return function(env)\n return "..str.."\n end"
	f = (loadstring s)!
	return f env

-- sigil helper function
alphanumeric = (c) -> if c\match("%w") then true else false 
entirely_whitespace = (s) -> if s\match("[^%s]") then false else true

-- data stack
-- list of items on the stack
-- stack_index points to the top stack item
local data_stack
local stack_index
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
local dictionary

-- definitions recursively call eval so here it is
local eval

-- parsing
parse = (s) ->
	program = s\gsub("([^%S ]+)"," %1 ")
	[word for word in string.gmatch program, "([^ ]+)"]
-- parsed is the result of parsing a program
-- current_word points 1 word before the next word in line for execution
local parsed
local current_word

get_word = ->
	current_word += 1
	-- TODO: error handling in the callers, not the callee
	-- if not parsed[current_word] then
	--	 error "RAN OUT OF WORDS"
	parsed[current_word]

unget_word = (word) ->
	parsed[current_word] = word
	current_word -= 1

-- user-defined lua functions, not to be called from moonwalk but from lua
local user_env
local checkpoint
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
	user_env.parse = parse
	user_env.read_file = read_file
	user_env.serialize = serialize
	user_env.deserialize = deserialize
	user_env.checkpoint = checkpoint
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
	write_file "new_state.state", serialize current_state
	rename_file "new_state.state", "current_state.state"
	delete_file "new_state.state"
store_state = save_state
checkpoint = save_state
restore_state = -> 
	str = read_file "current_state.state"
	if args[1]
		str = nil
	local old_state
	if str
		--print "OLD STATE GOTTEN"
		old_state = deserialize str, {}
	else
		--print "NEW STATE CREATED"
		local new_task_queue
		if args[1]
			new_task_queue = parse read_file args[1]
		else
			new_task_queue = parse ""
		old_state = {
			stack: {}
			task_queue: new_task_queue
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
		print body
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

-- predefined words
dictionary["pure"] = {
	type: "moonwalk"
	body: {}
}

dictionary["::"] = {
	type: "lua"
	body: '
		local name
		name = get_word()
		--print("DEFINING "..name)
		local recovery
		recovery = get_word()
		if not dictionary[recovery]  then
			error("INVALID RECOVERY WORD WHEN DEFINING "..name)
		end
		local prebody = ""
		if recovery ~= "pure" then
		  prebody = "unget_word(\\""..name.."\\")\\nunget_word(\\""..recovery.."\\")\\nunget_word(\\"boot_cooldown\\")\\ncheckpoint()\\nget_word()\\nget_word()\\nget_word()\\n"
		end
		local postbody = ""
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
					body=prebody..table.concat(body, " ")..postbody,
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

dictionary["include"] = {
	type: "lua"
	body: '
		local name = get_word()
		local code = parse(read_file(name))
		local i = table.getn(code)
		while i > 0 do
			unget_word(code[i])
			i = i - 1
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
		--print word
		eval word
delete_state!


-- TODO: make debugging programs easier.
