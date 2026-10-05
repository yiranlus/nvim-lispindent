# A SLIME-like Indenter implemented for Neovim

This plugin borrow the concept of SLIME's indenter to make Lisp well indented and easier to read. This plugin relies on a customized Lisp tree-sitter (which can be found [here](https://github.com/yiranlus/tree-sitter-lisp)). It has been tested with Common Lisp and Guile code.

**Note:**: this plugin is in early development, so advanced indentation rules like Common Lisp's `loop` were not implemented yet. Any contribution is welcome.

*This project is designed to be part of Common Lisp development environment which I have been working on for some time. However, this indenter can be used for different Lisp variants.*

## Installation

If you use `lazy.nvim`, you can add the plugin using following code:

```lua
{
  "yiranlus/nvim-lispindent",
  dependencies = {
    "yiranlus/tree-sitter-lisp"
  },
  ft = { "lisp", "scheme" },
  opts = {
    commonlisp = {
      enabled = true,
    },
    scheme = {
      enabled = true,
      features = {
        guile = true,
        guix = true,
      },
    },
  },
}
```

## Rules

The rules are very similar to that of SLIME. Each indent rule is a list which can contain sub-list and each list have two components;

* The indent of current list (similar to `&whole`)
* The indent of each element in the list

Unlike SLIME rules, the indent for the first element should also be specified, you can use either `NIL` (not Lua's `nil`) or `1`. There should be no difference between the two. The top-level rules should ignore the indent of current list and the first element.

You can also use shortcut like single number, which will generate a body-like indent rules like in SLIME. You can refer to [lua/lispindent/variants/commonlisp.lua] for concrete examples.
