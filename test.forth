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
:: {
	local block = {}
	block[1] = "{"
	local len = 1
	local depth = 1
	while true do
		local word = get_word()
		if word == "{" then
			depth = depth + 1
	    end
		if word == "}" then
			depth = depth - 1
	    end
		len = len + 1
		block[len] = word
		if depth == 0 then
			break
		end
	end
	push(block)
;;
:: times
	local iterations = pop()
	local block = pop()
	if iterations > 0 then
		unget_word("times")
		unget_word(tostring(iterations-1))
		unget_word("#")
		local len = table.getn(block)
		local templen = len
		while len > 0 do
			unget_word(block[len])
			len = len - 1
		end
		len = templen-1
		while len > 1 do
			unget_word(block[len])
			len = len - 1
		end
	end
;;
: inf # 1 # 0 div ;
: loop inf times ;
:: dup 
	local x = pop()
	push(x)
	push(x)
;;


: hi # 1 # 1 add # 3 mul ;
hi { dup print } hi times # 1 sub print
: lol hi print ;
{ lol } # 3 times
