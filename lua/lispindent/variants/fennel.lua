local LispIndenter = require("lispindent.core.indenter")

local FennelIndenter = {}
FennelIndenter.__index = FennelIndenter
setmetatable(FennelIndenter, { __index = LispIndenter })

function FennelIndenter:new(o)
  local instance = LispIndenter:new(o)
  return setmetatable(instance, self)
end

function FennelIndenter:default_indent_func(bufnr, lnum, state)
	local list_node = state.list_node
  local bracket_node = list_node:child(0)

	local _, base = list_node:start()

  if bracket_node and (bracket_node:text() == "{" or  bracket_node:text() == "[") then
    return base + 1
  end

  return LispIndenter.default_indent_func(self, bufnr, lnum, state)
end

--- in default case, only the last child of the list is meaningful
---@param bufnr number
---@param lnum number
---@param state State
function FennelIndenter:fn_indent_func(bufnr, lnum, state)
  local root_node = state.root_node
  local nested_indices = state.nested_indices
  local list_node = state.list_node
	local _, base = list_node:start()
    local index = nested_indices[1]

  if #nested_indices == 1 and index > 0 then
    state.spec = nil

    if root_node:named_child_count() >= 2 then
      local second_child = root_node:named_child(1)
      if second_child and second_child:type() == "list" then
        if index == 1 then
          return base + 4
        else
          return self:body_indent_func(bufnr, lnum, state)
        end
      else
        if 0 < index and index <= 2 then
          return base + 4
        end
      end
    end
    return self:body_indent_func(bufnr, lnum, state)
  end

  return self:default_indent_func(bufnr, lnum, state)
end

local I = {
  lambda = FennelIndenter.lambda_indent_func,
  body = FennelIndenter.body_indent_func,
}
NIL = FennelIndenter.NIL

function FennelIndenter.get_default_rules()
  return {
    rules = {
      ["accumulate"] = 1,
      ["faccumulate"] = "accumulate",
      ["case"] = {{4, "*", 1}, I.body},
      ["case-try"] = "case",
      ["collect"] = 1,
      ["fcollect"] = "collect",
      ["icollect"] = "collect",
      ["do"] = 0,
      ["each"] = 1,
      ["eval-compiler"] = 0,
      ["fn"] = FennelIndenter.fn_indent_func,
      ["lambda"] = FennelIndenter.fn_indent_func,
      ["for"] = 1,
      ["let"] = {{4, "*", 1}, I.body},
      ["macro"] = {4, 4, I.body},
      ["match"] = "case",
      ["match-try"] = "case",
      ["when"] = 1,
      ["while"] = 1,
      ["with-open"] = 1,
    },
  }
end

function FennelIndenter.get_default()
  return FennelIndenter:new(FennelIndenter.get_default_rules())
end

return FennelIndenter
