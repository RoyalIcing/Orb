# The raw ingredients of WebAssembly made beautiful, composable & reusable with Elixir

Orb is a fresh way to write WebAssembly. Instead of choosing an existing language like C and mapping its semantics to WebAssembly, Orb starts with the raw ingredients of WebAssembly and asks “how can we make this more convenient to write?”.

It achieves this by embracing the Elixir ecosystem at compile time. Elixir becomes a powerful preprocessor for WebAssembly.

You get to use:

- Elixir’s composable module system
- Elixir’s powerful macros
- Elixir’s existing ecosystem of libraries running at compile-time for your WebAssembly module
- Elixir’s [package manager Hex](https://hex.pm) for publishing your WebAssembly modules as reusable Elixir libraries.
- Elixir’s [testing library ExUnit](https://hexdocs.pm/ex_unit/ExUnit.html)
- Elixir language servers and syntax highlighting in Visual Studio Code, Zed & GitHub

Orb is Elixir at compile time and WebAssembly at runtime.

## Example

```elixir
defmodule TemperatureConverter do
  use Orb

  I32.export_enum([:celsius, :fahrenheit])

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

wasm_data = Orb.to_wasm(TemperatureConverter)
```

## Compile-time Macros

Orb lets you run any Elixir code at compile-time. You could read from the `Process` dictionary for feature flags, make a HTTP request, or call out to an Elixir library.
