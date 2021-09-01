# nvim-parinfer

nvim-parinfer is a Neovim plugin that uses [Chris Oakman's][oakmac]
[parinfer-lua][] to implement the [parinfer][] algorithm. Unlike
[parinfer-rust][], it requires no external dependencies: simply install and go.

[oakmac]: https://github.com/oakmac
[parinfer]: https://shaunlebron.github.io/parinfer/
[parinfer-rust]: https://github.com/eraserhd/parinfer-rust
[parinfer-lua]: https://github.com/oakmac/parinfer-lua

## Configuration

nvim-parinfer supports the following options:

`g:parinfer_mode`

**Default: `smart`**

What mode to use with the parinfer algorithm. See the [parinfer][] website for
more details. The recommended (and default) value is `smart`.

`g:parinfer_enabled`

**Default: `true`**

When `false`, parinfer will not run. You can control this variable with the
`:ParinferOn`, `:ParinferOff`, and `:ParinferToggle` commands.

`g:parinfer_force_balance`

**Default: `false`**

When `true`, indent mode will aggressively enforce paran balance.

`g:parinfer_comment_chars`

**Default: `[';']`**

List of characters that represent comments.

All of the options above can be set on a buffer-local basis as well (just use
`b:` instead of `g:`).

nvim-parinfer defines two mappings: `<Plug>(parinfer-tab)` and
`<Plug>(parinfer-backtab)`. These will move your cursor to special "tab stops"
as identified by parinfer. They will be mapped automatically to `<Tab>` and
`<S-Tab>` in Lisp buffers unless `g:parinfer_no_maps` is set to `1`.

## Architecture

The basic layout of this plugin is as follows:

`plugin/parinfer.vim` is loaded on startup and sets some default options and
autocommands.

Once a recognized filetype (essentially any Lisp) is opened in Neovim, parinfer
is initialized by calling `parinfer#init()` (defined in
`autoload/parinfer.vim`). This function in turn loads the Lua setup script
`parinfer.setup`, which is defined in `fnl/parinfer/setup.fnl`. This script
does all of the buffer management and communicates with the parinfer algorithm
implemented in `lua/parinfer.lua`.

Once Neovim adds support for defining autocommands directly in Lua, the
`plugin/parinfer.vim` and `autoload/parinfer.vim` files will be replaced with
pure Lua variants.

## License

`lua/parinfer.lua` is licensed ISC by [Chris Oakman][oakmac].

Everything else is licensed [GPLv3][] or later by Gregory Anders.

[GPLv3]: https://www.gnu.org/licenses/gpl-3.0.en.html
