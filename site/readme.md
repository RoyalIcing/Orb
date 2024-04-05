# The raw ingredients of WebAssembly made beautiful, composable, reusable with Elixir

Orb is a fresh way to write WebAssembly. Instead of choosing an existing language like C and having it map itself to WebAssembly, Orb starts with the raw ingredients of WebAssembly and asks “how can we make this more convenient to write?”.

It achieves this by embracing Elixir's existing ecosystem:

- Elixir’s composable module system
- Elixir’s powerful macros
- Elixir’s existing ecosystem of libraries, all of which can be run at compile-time for your WebAssembly module
- Elixir’s [package manager Hex](https://hex.pm) for publishing your WebAssembly modules as reusable libraries.
- Elixir’s [testing library ExUnit](https://hexdocs.pm/ex_unit/ExUnit.html)
- Elixir language servers in Visual Studio Code and Zed

Execute Elixir at compile time and WebAssembly at runtime.

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
