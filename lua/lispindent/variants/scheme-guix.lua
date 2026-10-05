local GuileIndenter = require("lispindent.variants.scheme-guile")

local GuixIndenter = {}
GuixIndenter.__index = GuixIndenter
setmetatable(GuixIndenter, { __index = GuileIndenter })

function GuixIndenter:new(o)
  local instance = GuileIndenter:new(o)
  return setmetatable(instance, self)
end

function GuixIndenter:modify_phases_indent_func(bufnr, lnum, state)
  local root_node = state.root_node
  local nested_indices = state.nested_indices

  if #nested_indices == 1 then
    state.spec = nil
    return self:body_indent_func(bufnr, lnum, state)
  elseif #nested_indices == 2 then
    local child_index = nested_indices[1]
    local child_node = root_node:named_child(child_index)
    table.remove(nested_indices, 1) -- Remove the first index to focus on the second level

    if child_node:type() == "list" then
      if child_node:named_child_count() == 0 then
        return self:default(bufnr, lnum, state)
      else
        local head_node = child_node:named_child(0)
        local head_text = vim.treesitter.get_node_text(head_node, bufnr)

        if head_text == "add-before" or head_text == "add-after" then
          state.spec = 2
          return self:body_indent_func(bufnr, lnum, state)
        elseif head_text == "replace" then
          state.spec = 1
          return self:body_indent_func(bufnr, lnum, state)
        end

        return self:default_indent_func(bufnr, lnum, state)
      end
    end
  end

  return self:default_indent_func(bufnr, lnum, state)
end

function GuixIndenter.get_default_rules()
  return GuixIndenter.merge_rules(
    GuileIndenter.get_default_rules(),
    {
      rules = {
        ["package"] = 0,
        ["package/inherit"] = 1,
        ["origin"] = 0,

        ["modify-phases"] = GuixIndenter.modify_phases_indent_func,
        ["modify-inputs"] = 1,
        ["substitute-keyword-arguments"] = 1,

        ["substitute*"] = 1,
        ["with-directory-excursion"] = 1,

        ["wrap-program"] = 1,
      }
    }
  )
end

function GuixIndenter.get_default()
  return GuixIndenter:new(GuixIndenter.get_default_rules())
end

return GuixIndenter
