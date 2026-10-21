local parser = require("lispindent.core.parser")

local M =  {
  -- a table of indenters, where the key is the langauge names
  indenters = {}
}

function M.indentexpr()
	local bufnr = vim.api.nvim_get_current_buf()
	local lnum = vim.v.lnum

  local lisp_indenter = vim.b[bufnr].lisp_indenter
  local indenter = M.indenters[lisp_indenter]

  return indenter:indent(bufnr, lnum)
end


local function create_autocmd(ft, indenter)
  -- only used for scheme
  -- queries = queries or ""
  local lang = vim.treesitter.language.get_lang(ft)
  if lang and indenter then
    M.indenters[lang] = indenter.get_default()
  end

  vim.api.nvim_create_autocmd("FileType", {
    pattern = ft,
    callback = function()
      local bufnr = vim.api.nvim_get_current_buf()

      -- use `indentexpr` for indentation
      vim.bo[bufnr].lisp = false
      vim.bo[bufnr].lispoptions = "expr:1"
      vim.bo[bufnr].commentstring = ";; %s"

      vim.bo[bufnr].indentexpr = "v:lua.require'lispindent'.indentexpr()"
      vim.bo[bufnr].indentkeys = "0},0),0],!^F,o,O,)"
      vim.b[bufnr].lisp_indenter = lang
    end,
  })
end

function M.setup(opts)
	opts = opts or {}

  if opts.use_lang then
    parser.use_lang = opts.use_lang
  end

	if opts.commonlisp and opts.commonlisp.enabled then
		local indenter = require("lispindent.variants.commonlisp")

		create_autocmd("lisp", indenter)
	end

	if opts.scheme and opts.scheme.enabled then
		local scheme_opts = opts.scheme
    local module_to_load = "lispindent.variants.scheme"

		if scheme_opts.variants then
			local variants = scheme_opts.variants
			if variants.guile or variants.guix then
				module_to_load = "lispindent.variants.scheme-guile"
			end
			if variants["guix"] then
				module_to_load = "lispindent.variants.scheme-guix"
			end
		end
    local indenter = require(module_to_load)

		create_autocmd("scheme", indenter)
	end

  if opts.fennel and opts.fennel.enabled then
    local indenter = require("lispindent.variants.fennel")

    create_autocmd("fennel", indenter)
  end

  if opts.clojure and opts.clojure.enabled then
    local indenter = require("lispindent.variants.clojure")

    create_autocmd("clojure", indenter)
  end

  if opts.hy and opts.hy.enabled then
    local indenter = require("lispindent.variants.hy")

    create_autocmd("hy", indenter)
  end
end

return M
