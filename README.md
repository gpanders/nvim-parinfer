# nvim-parinfer

nvim-parinfer is a Neovim plugin that uses [Chris Oakman's][oakmac]
[parinfer-lua][] to implement the [parinfer][] algorithm. Parinfer
automatically balances parentheses as you type when working in Lisp-family
languages. Unlike [parinfer-rust][], it requires no external dependencies:
simply install and go.

[oakmac]: https://github.com/oakmac
[parinfer]: https://shaunlebron.github.io/parinfer/
[parinfer-rust]: https://github.com/eraserhd/parinfer-rust
[parinfer-lua]: https://github.com/oakmac/parinfer-lua

## Requirements

Neovim 0.7 or later.

[Version 1.2.0][v1.2.0] works for older versions of Neovim.

[v1.2.0]: https://github.com/gpanders/nvim-parinfer/releases/tag/v1.2.0

## Configuration

nvim-parinfer uses sane defaults that should "just work". You can see the
(small) list of configuration knobs in `:help parinfer`.

## License

`lua/parinfer.lua` is licensed ISC by [Chris Oakman][oakmac].

Everything else is licensed [GPLv3][] or later by Gregory Anders.

[GPLv3]: https://www.gnu.org/licenses/gpl-3.0.en.html
