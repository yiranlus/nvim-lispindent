---@class State
---@field nested_indices number[] The indices of the nested lists leading to the current list
---@field arg_index number The index of the current argument in the list
---@field spec string|table|function? The indentation specification for the current list
---@field root_node TSNode The root node of the current list
---@field list_node TSNode The current list node

local LispParser = require("lispindent.core.parser")

local LispIndenter = {}
LispIndenter.__index = LispIndenter

NIL = {}
LispIndenter.NIL = NIL

function LispIndenter:new(o)
	o = o or {}
	o = {
		rules = o.rules or {},
		regex_rules = o.regex_rules or {},
		parser = o.parser or LispParser,
	}

	return setmetatable(o, self)
end

---@param bufnr number
---@param lnum number
---@param state State
function LispIndenter:default_indent_func(bufnr, lnum, state)
	-- in default case, only the last child of the list is meaningful
	state = state or {}
	local list_node = state.list_node

	local start_row, base = list_node:start()
	local raw_index = self.parser.raw_argument_position(bufnr, list_node, lnum)
	local nested_indices = state.nested_indices or {}
	local index = nested_indices[#nested_indices]

	if list_node and list_node:type() ~= "list" then
		return base
	end

	if not raw_index then
		return base + 1
	end

	if index < 0 then
		-- Inside the opening '('
		return base
	elseif index == 0 or index == 1 then
		return base + 1
	end

	-- Find the child with minimum index at that is at the last line
  local target_child_index = raw_index - 1
  local target_child = list_node:named_child(target_child_index)
  local target_row = target_child and target_child:start() or start_row

  while target_child_index > 0 and target_child and target_child:start() >= target_row do
    target_child_index = target_child_index - 1
    target_child = list_node:named_child(target_child_index)
  end
	target_child = list_node:named_child(target_child_index + 1)
	--#end_region

	if not target_child then
		-- Fallback if there is no second child
		return base + 1
	end

	local _, start_col = target_child:start() -- 0-based column of the target child

	-- Ensure we align to at least base+1
	return math.max(base + 1, start_col)
end

--- in default case, only the last child of the list is meaningful
---@param bufnr number
---@param lnum number
---@param state State
function LispIndenter:body_indent_func(bufnr, lnum, state)
	local list_node = state.list_node
	local _, base = list_node:start()
	return base + 2
end

-- in default case, only the last child of the list is meaningful
function LispIndenter:lambda_indent_func(bufnr, lnum, state)
	return self:default_indent_func(bufnr, lnum, state)
end

local function index_indent_spec(spec, nested_indices, rules)
	if #nested_indices == 0 then
		if type(spec) == "table" and spec ~= NIL then
			return spec[1]
		else
			return spec
		end
	end


	if type(spec) == "string" then
		if rules[spec] then
			if type(rules[spec]) == "number" then
				local tmp_spec = { NIL, NIL }
				for _ = 1, rules[spec] do
					table.insert(tmp_spec, 4)
				end
				table.insert(tmp_spec, "*")
				table.insert(tmp_spec, LispIndenter.body_indent_func)
				spec = tmp_spec
			elseif type(rules[spec]) == "table" then
				spec = { NIL, NIL, unpack(rules[spec]) }
			else
				error("Unknown indent spec type for rule: " .. spec)
			end
			return index_indent_spec(spec, nested_indices, rules)
    end

		error("Unknown indent spec: " .. spec)
	elseif type(spec) == "table" and spec ~= NIL then
		local index = nested_indices[1]
		local next_spec = nil

		if spec[#spec - 1] == "*" then
			if index + 2 < #spec - 1 then
				next_spec = spec[index + 2]
			else
				next_spec = spec[#spec]
			end
		else
			if index + 2 <= #spec then
				next_spec = spec[index + 2]
			else
				next_spec = nil
			end
		end

		-- return the next spec and the current index for further processing
		return index_indent_spec(next_spec, { unpack(nested_indices, 2) }, rules)
	end

	return nil
end

function LispIndenter:indent_slime_like(bufnr, lnum, state)
	state = state or {}

	local list_node = state.list_node
	local nested_indices = state.nested_indices or {}
	local spec = state.spec or nil

	-- This is a custom indent function for SLIME-like forms
	-- list_node is the direct parent list of the current line
	-- spec is a table of indent rules for the top-level list
	-- nested_index is the index of the nested list within the top-level list

	local rules = self.rules
	local _, base = list_node:start()

	if type(spec) == "string" and rules[spec] then
		-- state.spec = { NIL, NIL, unpack(rules[spec]) }
		return self:universal_indent_func(bufnr, lnum, state)
	end

	local indent_func = nil

	if type(spec) == "table" and spec ~= NIL then
		indent_func = index_indent_spec(spec, nested_indices, rules)
	elseif type(spec) == "function" then
		indent_func = spec
	end

	if type(indent_func) == "table" and indent_func ~= NIL then
		indent_func = indent_func[1]
	end

	if type(indent_func) == "function" then
		return indent_func(self, bufnr, lnum, state)
	elseif type(indent_func) == "number" then
		return base + indent_func
	end

	return self:default_indent_func(bufnr, lnum, state)
end

---param bufnr number
---param lnum number
---param state State
function LispIndenter:universal_indent_func(bufnr, lnum, state)
	state = state or {}

	local spec = state.spec or nil
	local rules = self.rules


	if type(spec) == "function" then
		return spec(self, bufnr, lnum, state)
	elseif type(spec) == "string" then
		if rules[spec] then
			if type(rules[spec]) == "number" then
				local tmp_spec = { NIL, NIL }
				for _ = 1, rules[spec] do
					table.insert(tmp_spec, 4)
				end
				table.insert(tmp_spec, "*")
				table.insert(tmp_spec, LispIndenter.body_indent_func)
				state.spec = tmp_spec
			elseif type(rules[spec]) == "table" then
				state.spec = { NIL, NIL, unpack(rules[spec]) }
			else
				error("Unknown indent spec type for rule: " .. spec)
			end
			return self:universal_indent_func(bufnr, lnum, state)
		end
		error("Unknown indent spec: " .. spec)
	elseif type(spec) == "table" and spec ~= NIL then
		return self:indent_slime_like(bufnr, lnum, state)
	end

	return self:default_indent_func(bufnr, lnum, state)
end

function LispIndenter:indent(bufnr, lnum)
	local rules = self.rules
	local regex_rules = self.regex_rules

	-- 1. Inside a multi-line token (e.g., long string)?
	if self.parser.is_inside_token(bufnr, lnum) then
		-- do nothing
		return vim.fn.indent(lnum)
	end

	-- 2. Inside a list?
	local list_node = self.parser.enclosing_list(bufnr, lnum)
	if not list_node then
		return 0
	end

	local arg_index = self.parser.argument_position(bufnr, list_node, lnum)
	local root_node, head_text, nested_indices = self.parser.nested_argument_position(bufnr, list_node, rules, regex_rules)
	nested_indices[#nested_indices + 1] = arg_index

	-- check for normal rules
	local spec = rules and rules[head_text] or nil
	regex_rules = regex_rules or {}

	if not spec and head_text then
		for pattern, regex_spec in pairs(regex_rules) do
			if vim.regex(pattern):match_str(head_text) then
				spec = regex_spec
				break
			end
		end
	end

	if type(spec) == "table" and spec ~= NIL then
		spec = { NIL, NIL, unpack(spec) }
	elseif type(spec) == "number" then
		local tmp_spec = { NIL, NIL }
		for _ = 1, spec do
			table.insert(tmp_spec, 4)
		end
		table.insert(tmp_spec, "*")
		table.insert(tmp_spec, LispIndenter.body_indent_func)
		spec = tmp_spec
	end

	return self:universal_indent_func(bufnr, lnum, {
		root_node = root_node,
		list_node = list_node,
		nested_indices = nested_indices,
		arg_index = arg_index,
		spec = spec,
	})
end

function LispIndenter:get_default_rules()
	error("get_default_rules is not implemented")
end

function LispIndenter:get_defuault()
	error("get_defuault is not implemented")
end

function LispIndenter.merge_rules(base, new)
	local merged_rules = vim.tbl_extend("force", base.rules or {}, new.rules or {})
	local merged_regex_rules = vim.tbl_extend("force", base.regex_rules or {}, new.regex_rules or {})
	return {
		rules = merged_rules,
		regex_rules = merged_regex_rules,
	}
end

return LispIndenter
