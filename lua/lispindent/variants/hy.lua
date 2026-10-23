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
        vim.treesitter.get_node_text(child, bufnr) == "#^"
      )
    )
    then

      local start_row = child:start()
      local prev_sibling = child:prev_named_sibling()

      if prev_sibling and prev_sibling:type() == "reader_macro" and
        vim.treesitter.get_node_text(prev_sibling, bufnr) == "#^"
      then
        goto continue
      end
      if start_row < target_row then
        count = count + 1
      else
        break
      end
    end
      ::continue::
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

      if found_async == nil then
        if child and vim.treesitter.get_node_text(child, bufnr) == ":async" then
          found_async = true
          goto continue
        else
          found_async = false
        end
      end

      if found_async ~= nil and found_decorator == nil then
        if child and child:type() == "list" then
          found_decorator = true
          goto continue
        else
          found_decorator = false
        end
      end

      if found_decorator ~= nil and found_tp == nil then
        if child and vim.treesitter.get_node_text(child, bufnr) == ":tp" then
          found_tp = true
          goto continue
        else
          found_tp = false
        end
      end

      if found_async ~= nil and found_decorator ~= nil and found_tp ~= nil then
        break
      end

      ::continue::
    end

    local count = (found_async and 1 or 0) + (found_decorator and 1 or 0) + (found_tp and 2 or 0)
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

      if found_decorator == nil then
        if child and child:type() == "list" then
          found_decorator = true
          goto continue
        else
          found_decorator = false
        end
      end

      if found_decorator ~= nil and found_tp == nil then
        if child and vim.treesitter.get_node_text(child, bufnr) == ":tp" then
          found_tp = true
          goto continue
        else
          found_tp = false
        end
      end

      if found_decorator ~= nil and found_tp ~= nil then
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
          found_tp = true
          goto continue
        else
          found_tp = false
        end
      end

      if found_tp ~= nil then
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

function HyIndenter:try_indent_func(bufnr, lnum, state)
  local nested_indices = state.nested_indices
  local index = nested_indices[1]
  local list_node = state.list_node
  local _, base = list_node:start()

  if #nested_indices == 1 and index > 0 then
    return self:body_indent_func(bufnr, lnum, state)
  elseif #nested_indices == 2 then
    if list_node:type() == "list" then
      local second_index = nested_indices[2]

      if second_index > 0 then
        local head_node = self.parser.get_named_child(list_node, 0)
        local head_text = vim.treesitter.get_node_text(head_node, bufnr)

        if head_text == "except" or
          head_text == "finally" then
          if second_index == 1 then
            return base + 4
          end
          return self:body_indent_func(bufnr, lnum, state)
        elseif head_text == "else" then
          return self:body_indent_func(bufnr, lnum, state)
        end

        return self:default_indent_func(bufnr, lnum, state)
      end
    end
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
      ["when"] = 1,
      ["with"] = 1,
      ["match"] = 1,
      ["while"] = 1,
      ["for"] = 1,
      ["lfor"] = 0,
      ["dfor"] = 0,
      ["gfor"] = 0,
      ["sfor"] = 0,
      ["cond"] = 0,
      ["do"] = 0,
      ["do-mac"] = 0,
      ["try"] = HyIndenter.try_indent_func,
      ["except"] = 1,
      ["else"] = 0,
      ["finally"] = 0,
      ["eval-and-compile"] = 0,
      ["eval-when-compile"] = 0,
      ["let"] = 1,
      -- Hyrule
      ["ap-each"] = 1,
      ["ap-each-while"] = 2,
      ["ap-dotimes"] = 1,
      ["ap-when"] = 1,
      ["ap-with"] = 1,
      ["doto"] = 1,
      ["block"] = 0,
      ["branch"] = 1,
      ["case"] = 1,
      ["cfor"] = 1,
      ["defmain"] = 1,
      ["do-n"] = 1,
      ["ebranch"] = "branch",
      ["ecase"] = "case",
      ["lif"] = 1,
      ["list-n"] = 1,
      ["loop"] = 1,
      ["unless"] = 1,
      ["defn+"] = HyIndenter.defn_indent_func,
      ["fn+"] = "fn",
      ["let+"] = "let",
      ["defmacro-kwargs"] = 2,
      ["defmacro!"] = "defmacro",
      ["meth"] = HyIndenter.defn_indent_func,
      ["ameth"] = HyIndenter.defn_indent_func,
      ["comment"] = 0,
      ["smacrolet"] = "let",
    },
  }
end

function HyIndenter.get_default()
  return HyIndenter:new(HyIndenter.get_default_rules())
end

return HyIndenter
