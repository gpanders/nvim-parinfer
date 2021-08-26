# nvim-parinfer

nvim-parinfer is a Neovim plugin that uses [Chris Oakman's][oakmac]
[parinfer-lua][] to implement the [parinfer][] algorithm. Unlike
[parinfer-rust][], it requires no external dependencies: simply install and go.

[oakmac]: https://github.com/oakmac
[parinfer]: https://shaunlebron.github.io/parinfer/
[parinfer-rust]: https://github.com/eraserhd/parinfer-rust
[parinfer-lua]: https://github.com/oakmac/parinfer-lua

## Description

The basic layout of this plugin is as follows:

`plugin/parinfer.vim` sets some default options and autocommands. Once a
recognized filetype (essentially any Lisp) is recognized in Neovim,
parinfer is initialized by calling `parinfer#init()` (defined in
`autoload/parinfer.vim`). This function in turn loads the Lua setup script
`parinfer.setup`, which is defined in `fnl/parinfer/setup.fnl`. This script
does all of the buffer management and communicates with the parinfer algorithm
implemented in `lua/parinfer.lua`.

## License

`lua/parinfer.lua` is licensed ISC by [Chris Oakman][oakmac].

`plugin/parinfer.vim` is heavily based on [Jason Felice's][eraserhd]
implementation in [parinfer-rust][] and is therefore also licensed ISC.

Everything else is licensed [GPLv3][] or later by Gregory Anders.

[eraserhd]: https://github.com/eraserhd
[GPLv3]: https://www.gnu.org/licenses/gpl-3.0.en.html
