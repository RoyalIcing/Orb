# Orb

## Write once, install everywhere you are
## Write once, add everywhere
## Write once, sprinkle everywhere
## Write once, deploy everywhere
## Elixir at compile time, WebAssembly at runtime

Orb is a fresh way to write WebAssembly. Instead of choosing an existing language like C and having it contort itself into WebAssembly, Orb starts with the raw ingredients of WebAssembly and asks “how can we make it way more convenient to write”.

It does this by leaning on Elixir's existing ecosystem:

- Elixir’s composable module system
- Elixir’s powerful macros
- Elixir’s [package manager Hex](https://hex.pm)
- Elixir’s [testing library ExUnit](https://hexdocs.pm/ex_unit/ExUnit.html)
- Extensive ecosystem of libraries, all of which can be run at compile time for your WebAssembly module
- Elixir language servers in Visual Studio Code and Zed

## Platform agnostic

Orb is unlike other WebAssembly systems in that it’s not trying to take an existing model like Lambda and make it WebAssembly flavoured. It aims to be broader by being agnostic to a particular target platform.

The strength of WebAssembly is that it can run anywhere:

- Web browsers
- Server (including edge)
- Mobile
- Desktop

So unlike projects like [`wasm-bindgen`](https://github.com/rustwasm/wasm-bindgen) or [Spin](https://github.com/fermyon/spin) Orb doesn't generate boilerplate JavaScript bindings or plug into a hosted service.

Orb lets you think and write in WebAssembly, working with the primitives it has via a little bit of Elixir sugar syntax.

It uses lightweight conventions that let it integrate into any platform. That way you can write once, and deploy anywhere.

