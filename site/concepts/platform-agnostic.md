# Platform agnostic

Orb is unlike other WebAssembly systems in that it’s not trying to take an existing model like Lambda and make it WebAssembly flavoured. It aims to be broader by being agnostic to a particular target platform.

The strength of WebAssembly is that it can run anywhere:

- Web browsers
- Server (including edge)
- Mobile
- Desktop

So unlike projects like [`wasm-bindgen`](https://github.com/rustwasm/wasm-bindgen) or [Spin](https://github.com/fermyon/spin) Orb doesn't generate boilerplate JavaScript bindings or plug into a hosted service.

Orb lets you think and write in WebAssembly, working directly with the primitives it has, with a little bit of Elixir sugar syntax.

It uses lightweight conventions that let you integrate into any platform. That way you can write once, and then plugin anywhere.
