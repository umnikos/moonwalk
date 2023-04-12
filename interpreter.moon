import open from io

DEBUG = false

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

-- FIXME FIXME FIXME: THIS IS SLOW AF AND IT'S CAUSING PROBLEMS
-- serialization and deserialization
serialize = (o) ->
	t = type o
	if "string" == t
		s = string.format "%q", o
		return s
	if "number" == t
		if o == 1/0
			return "(1/0)"
		return o
	if "table" == t
		s = "{ "
		for k,v in pairs(o)
			s = s.."["..(serialize k).."] = "..(serialize v)..", "
		return s.." }"
	if "function" == t
		str = string.dump o
		return "loadstring("..serialize(str)..")"
	if "boolean" == t
		return tostring(o)
	if "nil" == t
		return "nil"
	error "DIDN'T THINK OF TYPE "..(t).." FOR SERIALIZING"
deserialize = (str) ->
	s = "return "..str
	f = (loadstring s)!
	return f

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
-- local parsed
-- local current_word
local task_queue

-- TODO: `get_raw_word` for use in `"`
get_word = ->
	-- TODO: error handling in the callers, not the callee
	-- if not parsed[current_word] then
	--	 error "RAN OUT OF WORDS"
	if DEBUG
		print "!!!"..(string.sub task_queue, 1, 30).."!!!"
	s, e = string.find task_queue, "%S+"
	if not s
		return nil
	--print e
	word = string.sub task_queue, s, e
	--print word
	task_queue = string.sub task_queue, e+1
	if DEBUG
		print("{"..word.."}")
	return word

get_word_raw = ->
	if DEBUG
		print "!!!"..(string.sub task_queue, 1, 30).."!!!"
	if string.sub(task_queue,1,2) == "  "
		word = ""
		task_queue = string.sub task_queue, 2
		return word
	s, e = string.find task_queue, "[%S]+"
	if s ~= 1 and string.sub(task_queue,1,1) ~= " "
		s, e = string.find task_queue, "[^%S ]+"
	--print e
	word = string.sub task_queue, s, e
	--print word
	task_queue = string.sub task_queue, e+1
	if DEBUG
		print("{{"..word.."}}")
	return word

unget_word = (word) ->
	task_queue = word.." "..task_queue

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
	user_env.get_word_raw = get_word_raw
	user_env.unget_word = unget_word
	user_env.dictionary = dictionary
	--user_env.parse = parse
	user_env.read_file = read_file
	user_env.serialize = serialize
	user_env.deserialize = deserialize
	user_env.checkpoint = checkpoint
	user_env
restore_task_queue = (old_task_queue) ->
	task_queue = old_task_queue
restore_stack = (old_stack, old_stack_index) ->
	data_stack = old_stack
	stack_index = old_stack_index
restore_dictionary = (old_dictionary) ->
	dictionary = old_dictionary
save_state = -> 
	-- TODO: save env and dict only when they've changed to minimize IO
	-- (use __index and __newindex in a metatable to monitor for changes)
	current_state = {
		stack: data_stack
		task_queue: task_queue
		env: user_env
		dictionary: dictionary
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
		old_state = deserialize str
	else
		--print "NEW STATE CREATED"
		local new_task_queue
		if args[1]
			new_task_queue = read_file args[1]
		else
			new_task_queue = ""
		old_state = {
			stack: {}
			task_queue: new_task_queue
			env: {}
			dictionary: {}
			stack_index: 0
		}
	restore_dictionary old_state.dictionary
	restore_stack old_state.stack, old_state.stack_index
	restore_task_queue old_state.task_queue
	restore_env old_state.env
delete_state = ->
	delete_file "current_state.state"

restore_state!

-- evaluation of lua and moonwalk code
dictionary_lua_cache = { }
eval_lua = (body) ->
	cached = dictionary_lua_cache[body]
	f = nil
	if cached
		f = cached
	else
		f = loadstring body
		if not f then
			print body
			error "INVALID LUA DEFINITION"
		setfenv f, user_env
		dictionary_lua_cache[body] = f
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
		  prebody = "unget_word(\\""..name.."\\")\\nunget_word(\\""..recovery.."\\")\\nunget_word(\\"reboot_handler\\")\\ncheckpoint()\\nget_word()\\nget_word()\\nget_word()\\n"
		end
		local postbody = ""
		local body
		body = {}
		local length
		length = 0
		while true do
			local word
			word = get_word_raw()
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
		local code = read_file(name)
		if code then
			unget_word(code)
		end
	'
}

-- REPL
while true do
	if DEBUG
		print "---EVAL---"
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
