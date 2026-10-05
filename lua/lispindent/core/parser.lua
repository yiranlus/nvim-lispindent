LispParser = {}
LispParser.__index = LispParser

function LispParser.node_at_line(bufnr, lnum)
	local lang = vim.treesitter.language.get_lang(vim.bo.filetype)
	local parser = vim.treesitter.get_parser(bufnr, lang)
	if not parser then
		return nil
	end

	local tree = parser:parse()[1]
	if not tree then
		return nil
	end

	return vim.treesitter.get_node({
		bufnr = bufnr,
		pos = { lnum - 1, 0 },
		lang = lang,
	})
end

function LispParser.is_inside_token(bufnr, lnum)
	local node = LispParser.node_at_line(bufnr, lnum)
	if not node then
		return false
	end

	if node:type() == "token" then
		local start_row, _, end_row, _ = node:range()
		if start_row ~= end_row and lnum - 1 > start_row then
			return true
		end
	end

	return false
end

function LispParser.enclosing_list(bufnr, lnum)
	local node = LispParser.node_at_line(bufnr, lnum)
	if not node then
		return nil
	end

	while node and node:type() ~= "list" do
		node = node:parent()
	end

	local start_row = node:start()
	if start_row == lnum - 1 then
		-- if the list start at the current line, take it as argument
		node = node:parent()
	end

	return node
end

function LispParser.list_head_child(bufnr, list_node)
	-- a list is composed of '(' child [args...] ')'
	-- only token and args are named children
	if not list_node or list_node:type() ~= "list" then
		return nil, nil
	end

	local child_count = list_node:named_child_count()

	if child_count == 0 then
		return nil, nil
	end

	local head = list_node:named_child(0)

	local text = vim.treesitter.get_node_text(head, bufnr)
	return list_node, text
end

-- Returns 0-based arg index: -1 = '(', 0 = head, 1 = first arg, ...
function LispParser.argument_position(bufnr, list_node, lnum)
	local target_row = lnum - 1

	local count = 0
	for i = 0, list_node:named_child_count() - 1 do
		local child = list_node:named_child(i)
		if not child then
			break
		end

		if child:type() ~= "comment" then
			local start_row = child:start()
			if start_row < target_row then
				count = count + 1
			else
				break
			end
		end
	end

	return count
end

-- A modified vergion of `argument_position` that counts also the comment elements
function LispParser.raw_argument_position(bufnr, list_node, lnum)
	local target_row = lnum - 1

	local count = 0
	for i = 0, list_node:named_child_count() - 1 do
		local child = list_node:named_child(i)
		if not child then
			break
		end

		local start_row = child:start()
		if start_row < target_row then
			count = count + 1
		else
			break
		end
	end

	return count
end

function LispParser.nested_argument_position(bufnr, node, rules, regex_rules)
	-- get the nested index of `node` in its parent list,
	-- the procedure stops when the list head is found in the rules table
	local result = {}
	local head_text = nil
	if node:named_child_count() > 0 then
		head_text = vim.treesitter.get_node_text(node:named_child(0), bufnr)
	end
	if head_text and rules[head_text] then
		return node, head_text, result
	end
  for pattern, _ in pairs(regex_rules) do
    if head_text and vim.regex(pattern):match_str(head_text) then
      return node, head_text, result
    end
  end

	local parent = node:parent()
	while parent and parent:type() == "list" do
		if parent:named_child_count() > 0 then
			head_text = vim.treesitter.get_node_text(parent:named_child(0), bufnr)
		end

    local real_index = 0
		for i = 0, parent:named_child_count() - 1 do
			if parent:named_child(i):equal(node) then
				table.insert(result, real_index)
        break
			end
      if parent:named_child(i):type() ~= "comment" then
        real_index = real_index + 1
      end
		end

		if head_text and rules[head_text]  then
      break
		end

    local should_break = false
		for pattern, _ in pairs(regex_rules) do
			if head_text and vim.regex(pattern):match_str(head_text) then
        should_break = true
				break
			end
		end
    if should_break then
      break
    end

		node = parent
		parent = node:parent()
	end

	-- reverse the result to get the order from outermost to innermost
	for i = 1, math.floor(#result / 2) do
		local j = #result - i + 1
		result[i], result[j] = result[j], result[i]
	end

	return parent, head_text, result
end

return LispParser
