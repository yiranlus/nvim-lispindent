local LispParser = require("lispindent.core.parser")

SchemeParser = {}
SchemeParser.__index = LispParser
setmetatable(SchemeParser, { __index = LispParser })

-- Scheme has datum comments, so we need to skip them when counting argument positions
function SchemeParser.argument_position(bufnr, list_node, lnum)
  local target_row = lnum - 1

	local count = 0
	for i = 0, list_node:named_child_count() - 1 do
		local child = list_node:named_child(i)
		if not child then
			break
		end

    if child:type() ~= "comment" and not (
      child:type() == "reader_macro" and
      vim.treesitter.get_node_text(child, bufnr):sub(1, 2) == "#;"
    ) then

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

local SchemeIndenter = {}
SchemeIndenter.__index = SchemeIndenter
setmetatable(SchemeIndenter, { __index = LispIndenter })

function SchemeIndenter:new(o)
  local instance = LispIndenter:new({
    rules = o.rules or {},
    regex_rules = o.regex_rules or {},
    parser = o.parser or SchemeParser
  })
  return setmetatable(instance, self)
end

function SchemeIndenter:default_indent_func(bufnr, lnum, state)
  local list_node = state.list_node
  local nested_indices = state.nested_indices or {}
  local arg_index = self.parser.argument_position(bufnr, list_node, lnum)

  if #nested_indices >=1 then
    nested_indices[#nested_indices] = arg_index

    state.nested_indices = nested_indices
  end

  return LispIndenter.default_indent_func(self, bufnr, lnum, state)
end

local I = {
  lambda = SchemeIndenter.lambda_indent_func,
  body = SchemeIndenter.body_indent_func,
}

function SchemeIndenter.get_default_rules()
  return {
    rules = {
      ["begin"] = 0,
      ["case"] = 1,
      ["delay"] = 0,
      ["do"] = 2,
      ["lambda"] = 1,
      ["let"] = 1,
      ["let*"] = 1,
      ["letrec"] = 1,
      ["let-values"] = 1,
      ["let*-values"] = 1,
      ["and-let*"] = 1,
      ["sequence"] = 0,
      ["let-syntax"] = 1,
      ["letrec-syntax"] = 1,
      ["syntax-rules"] = 1,
      ["syntax-case"] = 2,
      ["with-syntax"] = 1,
      ["library"] = 1,
      -- Part of at least Guile, Chez Scheme, Chicken
      ["eval-when"] = 1,

      ["call-with-input-file"] = 1,
      ["call-with-port"] = 1,
      ["with-input-from-file"] = 1,
      ["with-input-from-port"] = 1,
      ["call-with-output-file"] = 1,
      ["with-output-to-file"] = 1,
      ["with-output-to-port"] = 1,
      ["call-with-values"] = 1,
      ["dynamic-wind"] = 3,
      -- R7RS
      ["when"] = 1,
      ["unless"] = 1,
      ["letrec*"] = 1,
      ["parameterize"] = 1,
      ["define-values"] = 1,
      ["define-record-type"] = 1,
      ["define-library"] = 1,
      ["guard"] = 1,
      -- SRFI-8
      ["receive"] = 2,
      -- SRFI 64
      ["test-group"] = 1,
      ["test-group-with-cleanup"] = 1,
      -- SRFI-204
      ["match"] = 1,
      ["match-lambda"] = 0,
      ["match-lambda*"] = 0,
      ["match-let"] = "let",
      ["match-let*"] = 1,
      ["match-letrec"] = 1,
      -- SRFI-227
      ["opt-lambda"] = 1,
      ["opt*-lambda"] = 1,
      ["let-optionals"] = 2,
      ["let-optionals*"] = 2,
      -- SRFI-253
      ["check-case"] = 1,
      ["lambda-checked"] = 1,
      -- from Geiser
      ["case-lambda"] = 1,
      ["catch"] = 1, 
      ["class"] = 1,
    },

    regex_rules = {
      ["^define-\\?"] = 1,
    }
  }
end

function SchemeIndenter.get_default()
  return SchemeIndenter:new(SchemeIndenter.get_default_rules())
end

return SchemeIndenter
