local GuileIndenter = require("lispindent.variants.scheme-guile")

local GuixIndenter = {}
GuixIndenter.__index = GuixIndenter
setmetatable(GuixIndenter, { __index = GuileIndenter })

function GuixIndenter:new(o)
  local instance = GuileIndenter:new(o)
  return setmetatable(instance, self)
end

function GuixIndenter:modify_phases_indent_func(bufnr, lnum, state)
  local nested_indices = state.nested_indices
  local index = nested_indices[1]
  local list_node = state.list_node

  print("modify_phases_indent_func called with nested_indices: " .. vim.inspect(nested_indices))
  print("modify_phases_indent_func called with index: " .. index)

  if #nested_indices == 1 then
    if index == 1 then
      local _, base = list_node:start()
      return base + 4
    end
    return self:body_indent_func(bufnr, lnum, state)
  elseif #nested_indices == 2 then
    -- table.remove(nested_indices, 1) -- Remove the first index to focus on the second level
    print("Second level node type: " .. list_node:type())

    if list_node:type() == "list" then
      if list_node:named_child_count() == 0 then
        return self:default(bufnr, lnum, state)
      else
        local head_node = self.parser.get_named_child(list_node, 0)
        local head_text = vim.treesitter.get_node_text(head_node, bufnr)

        if head_text == "add-before" or head_text == "add-after" then
          print("add-before or add-after")
          local second_index = nested_indices[2]
          print("second_index: " .. second_index)
          if second_index == 1 or second_index == 2 then
            local _, base = list_node:start()
            return base + 4
          end
          return self:body_indent_func(bufnr, lnum, state)
        elseif head_text == "replace" then
          local second_index = nested_indices[2]
          if second_index == 1 then
            local _, base = list_node:start()
            return base + 4
          end
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
