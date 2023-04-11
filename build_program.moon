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

startup = '
	shell.run("interpreter",'..serialize(args[1])..')
	shell.run("bundle_state_as_program")
	shell.run("emu","close")
'
delete_file "out.lua"
os.execute "moonc interpreter.moon"
write_file "startup.lua", startup
os.execute "./ccemux -c ."
delete_file "startup.lua"
