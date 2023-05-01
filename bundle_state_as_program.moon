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

state = read_file "current_state.state"
interpreter = read_file "interpreter.lua"
startup = 'shell.run("moonwalk_interpreter")'
output = '
	file = fs.open("current_state.state","w") 
	file.write('..serialize(state)..')
	file.close()
	file = fs.open("current_state.valid","w") 
	file.write("true")
	file.close()
	file = fs.open("moonwalk_interpreter.lua","w") 
	file.write('..serialize(interpreter)..')
	file.close()
	file = fs.open("startup","w") 
	file.write('..serialize(startup)..')
	file.close()
	os.reboot()
'
write_file "out.lua", output
