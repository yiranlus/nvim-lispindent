local LispParser = require("lispindent.core.parser")

HyParser = {}
HyParser.__index = LispParser
setmetatable(HyParser, { __index = LispParser })

-- Hy has datum comments, so we need to skip them when counting argument positions
---@param bufnr number
---@param list_node TSNode
---@param lnum number
function HyParser.argument_position(bufnr, list_node, lnum)
  local target_row = lnum - 1

	local count = 0
	for i = 0, list_node:named_child_count() - 1 do
		local child = list_node:named_child(i)
		if not child then
			break
		end

    if child:type() ~= "comment" and not (
      child:type() == "reader_macro" and (
        vim.treesitter.get_node_text(child, bufnr):sub(1, 2) == "#;" or
        vim.treesitter.get_node_text(child, bufnr):sub(1, 2) == "#^"
      )
    )
    then

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

local LispIndenter = require("lispindent.core.indenter")

local HyIndenter = {}
HyIndenter.__index = HyIndenter
setmetatable(HyIndenter, { __index = LispIndenter })

function HyIndenter:new(o)
  local instance = LispIndenter:new({
    rules = o.rules or {},
    regex_rules = o.regex_rules or {},
    parser = o.parser or HyParser
  })
  return setmetatable(instance, self)
end

function HyIndenter:default_indent_func(bufnr, lnum, state)

	local list_node = state.list_node
  local bracket_node = list_node:child(0)

	local _, base = list_node:start()

  if bracket_node then
    local text = vim.treesitter.get_node_text(bracket_node, bufnr)
    if text == "{" or text == "[" then
      return base + 1
    end
  end

  return LispIndenter.default_indent_func(self, bufnr, lnum, state)
end

--- in default case, only the last child of the list is meaningful
---@param bufnr number
---@param lnum number
---@param state State
function HyIndenter:defn_indent_func(bufnr, lnum, state)
  local root_node = state.root_node
  local nested_indices = state.nested_indices
  local list_node = state.list_node
	local _, base = list_node:start()
  local index = nested_indices[1]

  if #nested_indices == 1 and index > 0 then
    state.spec = nil

    local found_async = nil
    local found_decorator = nil
    local found_tp = nil
    for i = 1, index do
      local child = root_node:named_child(i)

      print("child: ", child and vim.treesitter.get_node_text(child, bufnr) or "nil")

      if found_async == nil then
        if child and vim.treesitter.get_node_text(child, bufnr) == ":async" then
          print("found async")
          found_async = true
          goto continue
        else
          print("not found async")
          found_async = false
        end
      end

      if found_async ~= nil and found_decorator == nil then
        if child and child:type() == "list" then
          print("found decorator")
          found_decorator = true
          goto continue
        else
          print("not found decorator")
          found_decorator = false
        end
      end

      if found_decorator ~= nil and found_tp == nil then
        if child and vim.treesitter.get_node_text(child, bufnr) == ":tp" then
          print("found tp")
          found_tp = true
          goto continue
        else
          print("not found tp")
          found_tp = false
        end
      end

      if found_async ~= nil and found_decorator ~= nil and found_tp ~= nil then
        print("break at index: ", i)
        break
      end

      ::continue::
    end

    local count = (found_async and 1 or 0) + (found_decorator and 1 or 0) + (found_tp and 2 or 0)
    print("count: ", count, " index: ", index)
    if index <= count + 2 then
      return base + 4
    end

    return self:body_indent_func(bufnr, lnum, state)
  end

  return self:default_indent_func(bufnr, lnum, state)
end


function HyIndenter:defclass_indent_func(bufnr, lnum, state)
  local root_node = state.root_node
  local nested_indices = state.nested_indices
  local list_node = state.list_node
  local _, base = list_node:start()
  local index = nested_indices[1]

  if #nested_indices == 1 and index > 0 then
    state.spec = nil

    local found_decorator = nil
    local found_tp = nil
    for i = 1, index do
      local child = root_node:named_child(i)

      print("child: ", child and vim.treesitter.get_node_text(child, bufnr) or "nil")

      if found_decorator == nil then
        if child and child:type() == "list" then
          print("found decorator")
          found_decorator = true
          goto continue
        else
          print("not found decorator")
          found_decorator = false
        end
      end

      if found_decorator ~= nil and found_tp == nil then
        if child and vim.treesitter.get_node_text(child, bufnr) == ":tp" then
          print("found tp")
          found_tp = true
          goto continue
        else
          print("not found tp")
          found_tp = false
        end
      end

      if found_decorator ~= nil and found_tp ~= nil then
        print("break at index: ", i)
        break
      end

      ::continue::
    end

    local count = (found_decorator and 1 or 0) + (found_tp and 2 or 0)
    if index <= count + 2 then
      return base + 4
    end

    return self:body_indent_func(bufnr, lnum, state)
  end

  return self:default_indent_func(bufnr, lnum, state)
end


function HyIndenter:deftype_indent_func(bufnr, lnum, state)
  local root_node = state.root_node
  local nested_indices = state.nested_indices
  local list_node = state.list_node
  local _, base = list_node:start()
  local index = nested_indices[1]

  if #nested_indices == 1 and index > 0 then
    state.spec = nil

    local found_tp = nil
    for i = 1, index do
      local child = root_node:named_child(i)

      if found_tp == nil then
        if child and vim.treesitter.get_node_text(child, bufnr) == ":tp" then
          print("found tp")
          found_tp = true
          goto continue
        else
          print("not found tp")
          found_tp = false
        end
      end

      if found_tp ~= nil then
        print("break at index: ", i)
        break
      end

      ::continue::
    end

    local count = (found_tp and 2 or 0)
    if index <= count + 2 then
      return base + 4
    end

    return self:body_indent_func(bufnr, lnum, state)
  end

  return self:default_indent_func(bufnr, lnum, state)
end

local I = {
  lambda = HyIndenter.lambda_indent_func,
  body = HyIndenter.body_indent_func,
}
NIL = HyIndenter.NIL

function HyIndenter.get_default_rules()
  return {
    rules = {
      ["fn"] = 1,
      ["defn"] = HyIndenter.defn_indent_func,
      ["defmacro"] = 2,
      ["defreader"] = 1,
      ["deftype"] = HyIndenter.deftype_indent_func,
      ["defclass"] = HyIndenter.defclass_indent_func,
      ["if"] = 1,
      ["when"] = 1,
      ["unless"] = 1,
      ["with"] = 1,
      ["match"] = 1,
      ["branch"] = 1,
      ["while"] = 1,
      ["for"] = 1,
      ["lfor"] = 0,
      ["dfor"] = 0,
      ["gfor"] = 0,
      ["sfor"] = 0,
      ["cond"] = 0,
      ["do"] = 0,
      ["do-mac"] = 0,
      ["try"] = 0,
      ["except"] = 1,
      ["else"] = 0,
      ["finally"] = 0,
      ["eval-and-compile"] = 0,
      ["eval-when-compile"] = 0,
      ["let"] = 1,
      ["require"] = 0,
      ["import"] = 0,
    },
  }
end

function HyIndenter.get_default()
  return HyIndenter:new(HyIndenter.get_default_rules())
end

return HyIndenter
