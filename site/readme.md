# Orb

## Write once, install everywhere you are
## Write once, add everywhere
## Write once, deploy everywhere
## Elixir at compile time, WebAssembly at runtime

Orb is a fresh way to write WebAssembly. Instead of choosing an existing language like C and having it contort itself into WebAssembly, Orb starts with the raw ingredients of WebAssembly and asks "how can we make it way more convenient to write".

It does this by leaning on Elixir's existing ecosystem:

- Elixir’s composable module system
- Elixir’s powerful macros
- Elixir’s Hex package manager
- ExUnit testing library
- Extensive ecosystem of libraries that can be run at compile time
- Language servers in IDEs like Visual Studio Code and Zed

## Platform agnostic

Orb is unlike other WebAssembly systems in that it's not trying to take an existing model like Lambda and make it WebAssembly flavoured.

The strength of WebAssembly is that it can run anywhere, including essentially on users’ devices in their browsers.

Orb aims to let you target wherever WebAssembly can run:

- Web browser
- Server (including edge)
- Mobile
- Desktop

So Orb doesn't generate boilerplate JavaScript bindings or plug into a hosted service.

Instead it uses lightweight conventions that let it integrate into any platform.

That way you can write once, and deploy anywhere.

