:: one push(1) ;;
:: print print(pop()) ;;
:: add push(pop()+pop()) ;;
:: loop{
	local code
	code = {}
	local len
	len = 0
	local depth
	depth = 1
	while true do
		local word
		word = get_word()
		if word:match("{") then
			depth = depth + 1
		end
		if word:match("}") then
			depth = depth - 1
		end
		if depth == 0 then
			-- time for magic
			unget_word("}")
			local templen = len
			while len > 0 do
				unget_word(code[len])
				len = len - 1
			end
			unget_word("loop{")
			len = templen
			while len > 0 do
				unget_word(code[len])
				len = len - 1
			end
			break
		else
			len = len + 1
			code[len] = word
		end
			
	end
;;


: hi one one add print ;
loop{ hi }