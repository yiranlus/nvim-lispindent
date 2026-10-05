local LispIndenter = require("lispindent.core.indenter")

local CommonLispIndenter = {}
CommonLispIndenter.__index = CommonLispIndenter
setmetatable(CommonLispIndenter, { __index = LispIndenter })

function CommonLispIndenter:new(o)
  local instance = LispIndenter:new(o)
  return setmetatable(instance, self)
end

local I = {
  lambda = CommonLispIndenter.lambda_indent_func,
  body = CommonLispIndenter.body_indent_func,
}
NIL = CommonLispIndenter.NIL

function CommonLispIndenter:indent_loop_func(bufnr, lnum, state)
  local root_node = state.root_node
  local list_node = state.list_node
  local nested_indices = state.nested_indices
  local spec = state.spec or nil

  local rules = self.rules
  if #nested_indices > 1 then
    return I.default_indent_func(bufnr, lnum, list_node, nested_indices, rules)
  end

  local start_row, base = root_node:start()
  local arg_index = nested_indices[#nested_indices]
  if arg_index == 1 then
    return self:body_indent_func(bufnr, lnum, root_node, list_node, nested_indices)
  end

  _, base = root_node:named_child(1):start()

  -- local arg_index = nested_indices[#nested_indices]
  -- local last_arg = root_node:named_child(root_node:named_child_count() - 1)
  -- local last_arg_text = vim.treesitter.get_node_text(last_arg, bufnr)
  --
  -- if last_arg_text == "do" then
  --   local last_arg_row = last_arg:start()
  --   local llast_arg_row = root_node:named_child(root_node:named_child_count() - 2):start()
  --
  --   if last_arg_row == llast_arg_row then
  --     return base + 2
  --   else
  --     return base + 4
  --   end
  -- end
  --
  -- if arg_index < root_node:named_child_count() then
  --   local arg_text = vim.treesitter.get_node_text(root_node:named_child(arg_index), bufnr)
  --   if arg_text == "into" or arg_text == "to" or arg_text == "below"
  --     or arg_text == "downto" or arg_text = "above" or arg_text == "across"
  --     or arg_text == "being" or arg_text == "then" then
  --     return base + 2
  --   end
  -- end

  return base
end

function CommonLispIndenter.get_default_rules()
  return {
    rules = {
      ["block"] = 1,
      ["case"] = { 4, "*", { 2, "*", 1 } },
      ["ccase"] = "case",
      ["ecase"] = "case",
      ["typecase"] = "case",
      ["etypecase"] = "case",
      ["ctypecase"] = "case",
      ["catch"] = { 4, "*", 2},
      ["cond"] = { "*", { 2, "*", nil } },
      -- for DEFSTRUCT
      ["defvar"] = { 4, 2, 2 },
      ["defclass"] = { 6, { 4, "*", 1 }, { 2, "*", 1 }, { 2, "*", 1 } },
      ["defconstant"] = "defvar",
      ["defcustom"] = { 4, 2, 2, 2 },
      ["define-compiler-macro"] = "defun",
      ["defparameter"] = "defvar",
      ["defconst"] = "defcustom",
      ["define-condition"] = "defclass",
      ["define-modify-macro"] = { { 4, "*", I.lambda }, "*", I.body },
      -- -- ["define-setf"] = indent_defsetf,
      ["defun"] = { { 4, "*", I.lambda }, "*", I.body },
      ["defgeneric"] = { { 4, "&" }, "*", I.body },
      ["define-setf-method"] = "defun",
      ["define-setf-expander"] = "defun",
      ["defmacro"] = "defun",
      ["defsubst"] = "defun",
      ["deftype"] = "defun",
      -- ["defmethod"] = indent_defmethod,
      ["defpackage"] = { 4, "*", 2 },
      ["defstruct"] = { { 4, "*", { 2, "*", 1 } }, "*", { 2, "*", 1 } },
      ["destructuring-bind"] = { 4, 4, "*", I.body },
      -- ["do"] = indent_do,
      -- ["do*"] = "do",
      ["dolist"] = { { 4, 2, 1 }, "*", I.body },
      ["dotimes"] = "dolist",
      ["eval-when"] = 1,
      ["flet"] = { { 4, "*", { 1, NIL, { 4, "*", I.lambda }, "*", I.body } }, "*", I.body },
      ["labels"] = "flet",
      ["macrolet"] = "flet",
      ["generic-flet"] = "flet",
      ["generic-labels"] = "flet",
      ["handler-case"] = { 4, "*", { 2, NIL, 4, "*", I.body } },
      ["restart-case"] = "handler-case",
      -- single-else style (then and else equally indented)
      -- ["if*"] = lisp-indent-if*,
      -- ["lambda"] = { "&", "*", lisp-indent-function-lambda-hack }
      ["lambda"] = { {4, "*", I.lambda}, "*", I.body },
      ["let"] = { { 4, "*", { 1, NIL, 2 } }, "*", I.body },
      ["let*"] = "let",
      ["compiler-let"] = "let",
      ["handler-bind"] = "let",
      ["restart-bind"] = "let",
      ["locally"] = 1,
      ["loop"] = CommonLispIndenter.indent_loop_func,
      -- [":method"] = indent_defmethod,
      ["multiple-value-bind"] = { { 6, "*", 1 }, 4, "*", I.body },
      ["multiple-value-call"] = { 4, "*", I.body },
      ["multiple-value-prog1"] = 1,
      ["multiple-value-setq"] = { 4, 2 },
      ["multiple-value-setf"] = "multiple-value-setq",
      -- ["named-lambda"] = { 4, "&", "*", lisp-indent-function-lambda-hack },
      ["pprint-logical-block"] = { 4, 2 },
      ["print-unreadable-object"] = { { 4, NIL, "*", 1 }, "*", I.body },
      -- ["prog"] = { "&", "*", indent_tagbody },
      ["prog*"] = "prog",
      ["progn"] = 0,
      ["prog1"] = 1,
      ["prog2"] = 2,
      ["progv"] = 2,
      ["return"] = 0,
      ["return-from"] = 1,
      ["symbol-macrolet"] = "let",
      -- ["tagbody"] = indent_tagbody,
      ["throw"] = 1,
      ["unless"] = 1,
      ["unwind-protect"] = { 5, 2 },
      ["when"] = 1,
      ["with-accessors"] = "multiple-value-bind",
      ["with-compilation-unit"] = { { 4, "*", 1 }, "*", I.body },
      ["with-condition-restarts"] = "multiple-value-bind",
      ["with-output-to-string"] = { 4, 2 },
      ["with-slots"] = "multiple-value-bind",
      ["with-standard-io-syntax"] = { 2 },
    },
    regex_rules = {
      ["^\\(define-\\|do-\\|with-\\|without-\\)"] = 1,
      [":\\(define-\\|do-\\|with-\\|without-\\)"] = 1,
    }
  }
end

function CommonLispIndenter.get_default()
  return CommonLispIndenter:new(CommonLispIndenter.get_default_rules())
end

return CommonLispIndenter
