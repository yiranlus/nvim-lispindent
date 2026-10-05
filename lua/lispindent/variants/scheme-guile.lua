local SchemeIndenter = require("lispindent.variants.scheme")

local GuileIndenter = {}
GuileIndenter.__index = GuileIndenter
setmetatable(GuileIndenter, { __index = SchemeIndenter })

function GuileIndenter:new(o)
  local instance = SchemeIndenter:new(o)
  return setmetatable(instance, self)
end

local I = {
  lambda = GuileIndenter.lambda_indent_func,
  body = GuileIndenter.body_indent_func,
}

function GuileIndenter.get_default_rules()
  return GuileIndenter.merge_rules(
    SchemeIndenter.get_default_rules(),
    {
      rules = {
        ["lambda*"] = "lambda",

        ["c-declare"] = 0,
        ["c-lambda"] = 2,
        ["call-with-input-string"] = 1,
        ["call-with-output-string"] = 0,
        ["call-with-prompt"] = 1,
        ["call-with-trace"] = 0,
        ["eval-when"] = 1,
        ["pmatch"] = "defun",
        ["sigaction"] = 1,
        ["syntax-parameterize"] = 1,
        ["with-error-to-file"] = 1,
        ["with-error-to-port"] = 1,
        ["with-error-to-string"] = 0,
        ["with-fluid*"] = 1,
        ["with-fluids"] = 1,
        ["with-fluids*"] = 1,
        ["with-input-from-string"] = 1,
        ["with-method"] = 1,
        ["with-mutex"] = 1,
        ["with-output-to-string"] = 0,
        ["with-throw-handler"] = 1
      },

      regex_rules = {
        ["^with-"] = 1
      }
    }
  )
end

function GuileIndenter.get_default()
  return GuileIndenter:new(GuileIndenter.get_default_rules())
end

return GuileIndenter
