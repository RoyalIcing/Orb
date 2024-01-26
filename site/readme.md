# Orb

## Elixir at compile time, WebAssembly at runtime

Orb is a fresh way to write WebAssembly. Instead of choosing an existing language, and having it spit out WebAssembly, Orb starts with WebAssembly and asks "how can we make it more convenient to write".

It does this by leaning on Elixir's existing ecosystem:

- Composable module system
- Powerful macros
- Hex package manager
- ExUnit testing library
- Integration with IDEs like Visual Studio Code and Zed

## Platform agnostic

Orb is also unlike other WebAssembly libraries in that it's not trying to take an existing model like Lambda and make it WebAssembly flavoured.

The strength of WebAssembly is that it can run anywhere, including most importantly on users’ devices in their browsers.

Orb aims to let you target wherever WebAssembly can run:

- Web browser
- Server (including edge)
- Mobile
- Desktop

So Orb doesn't generate boilerplate JavaScript code or bindings to a hosted service.

Instead it uses light weight conventions that can integrate into any platform.

That way you can write once, and install anywhere.

