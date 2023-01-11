:: print print(pop()) ;;
:: add push(pop()+pop()) ;;
:: mul push(pop()*pop()) ;;
:: sub 
	local y = pop()
	local x = pop()
	push(x-y)
;;
:: div
	local y = pop()
	local x = pop()
	push(x/y)
;;
:: # push(tonumber(get_word())) ;;
:: times{
	local iterations = pop()
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
			if iterations <= 0 then
				break
			end
			-- time for magic
			unget_word("}")
			local templen = len
			while len > 0 do
				unget_word(code[len])
				len = len - 1
			end
			unget_word("times{")
			unget_word(tostring(iterations-1))
			unget_word("#")
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
: loop{ # 1 # 0 div times{ ;


: hi # 1 # 1 add # 3 mul print ;
loop{ hi }