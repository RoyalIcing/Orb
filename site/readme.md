# The raw ingredients of WebAssembly with Elixir sugar on top

## Execute Elixir at compile time and WebAssembly at runtime

Orb is a fresh way to write WebAssembly. Instead of choosing an existing language like C and having it map itself to WebAssembly, Orb starts with the raw ingredients of WebAssembly and asks “how can we make this way more convenient to write?”.

It achieves this by embracing Elixir's existing ecosystem:

- Elixir’s composable module system
- Elixir’s powerful macros
- Elixir’s [package manager Hex](https://hex.pm) for publishing your WebAssembly modules as reusable libraries.
- Elixir’s [testing library ExUnit](https://hexdocs.pm/ex_unit/ExUnit.html)
- Elixir’s existing ecosystem of libraries, all of which can be run at compile-time for your WebAssembly module
- Elixir language servers in Visual Studio Code and Zed

## Platform agnostic

Orb is unlike other WebAssembly systems in that it’s not trying to take an existing model like Lambda and make it WebAssembly flavoured. It aims to be broader by being agnostic to a particular target platform.

The strength of WebAssembly is that it can run anywhere:

- Web browsers
- Server (including edge)
- Mobile
- Desktop

So unlike projects like [`wasm-bindgen`](https://github.com/rustwasm/wasm-bindgen) or [Spin](https://github.com/fermyon/spin) Orb doesn't generate boilerplate JavaScript bindings or plug into a hosted service.

Orb lets you think and write in WebAssembly, working directly with the primitives it has, with a little bit of Elixir sugar syntax.

It uses lightweight conventions that let you integrate into any platform. That way you can write once, and then plugin anywhere.

## Example

```elixir
defmodule TemperatureConverter do
  use Orb

  Orb.I32.export_enum([:celsius, :fahrenheit])

  global do
    @mode 0
  end

  defw celsius_to_fahrenheit(celsius: F32), F32 do
    celsius * (9.0 / 5.0) + 32.0
  end

  defw fahrenheit_to_celsius(fahrenheit: F32), F32 do
    (fahrenheit - 32.0) * (5.0 / 9.0)
  end

  defw convert_temperature(temperature: F32), F32 do
    if @mode === @celsius do
      celsius_to_fahrenheit(temperature)
    else
      fahrenheit_to_celsius(temperature)
    end
  end

  defw set_mode(mode: I32) do
    @mode = mode
  end
end
```

## Compile-time Macros

Orb lets you run any Elixir code at compile-time. You could read from the `Process` dictionary for feature flags, make a HTTP request, or call out to an Elixir library.
