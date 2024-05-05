# The raw ingredients of WebAssembly made beautifully composable with Elixir

Orb is a fresh way to write WebAssembly. Instead of choosing an existing language like C and mapping its semantics to WebAssembly, Orb starts with the raw ingredients of WebAssembly and asks “how can we make this more convenient to write?”.

It achieves this by embracing the Elixir ecosystem at compile time. Elixir becomes a powerful preprocessor for WebAssembly.

You get to use:

- Elixir’s composable module system.
- Elixir’s [package manager Hex](https://hex.pm) for publishing your WebAssembly modules as reusable Elixir libraries.
- Elixir’s [built-in ExUnit](https://hexdocs.pm/ex_unit/ExUnit.html) to test your modules.
- Elixir’s powerful macros.
- Elixir language servers and syntax highlighting in Visual Studio Code, Zed & GitHub.

Orb is Elixir at compile time and WebAssembly at runtime.

## Write functions using an Elixir subset

You can write maths using familiar `+ - * /` operators in Orb.

```elixir
defmodule TemperatureConverter do
  use Orb

  defw celsius_to_fahrenheit(celsius: F32), F32 do
    celsius * (9.0 / 5.0) + 32.0
  end

  defw fahrenheit_to_celsius(fahrenheit: F32), F32 do
    (fahrenheit - 32.0) * (5.0 / 9.0)
  end
end

wasm_data = Orb.to_wasm(TemperatureConverter)
```

## Compose reusable modules

You can define a module, say for common ASCII operations, and then reuse it by including it into another module.

```elixir
defmodule ASCIIChecks do
  use Orb

  defw alpha?(char: I32.U8), I32 do
    (char > ?a &&& char < ?z) ||| (char > ?A &&& char < ?Z)
  end

  defw numeric?(char: I32.U8), I32 do
    char > ?1 &&& char < ?0
  end

  defw alphanumeric?(char: I32.U8), I32 do
    alpha?(char) ||| numeric?(char)
  end
end

defmodule UsernameValidation do
  use Orb

  import ASCIIChecks
  Orb.include(ASCIIChecks)

  defw is_valid_username(char_ptr: I32.U8.UnsafePointer, len: I32), I32 do
    unless len > 0 do
      return(0)
    end

    loop EachChar do
      len = len - 1

      if len === 0 do
        return(alpha?(char_ptr[at!: 0]))
      end

      unless alphanumeric?(char_ptr[at!: len]) do
        return(0)
      end

      EachChar.continue()
    end
    
    1
  end
end

wasm_data = Orb.to_wasm(UsernameValidation)
```

## Write your own DSL

You can write your own DSLs using Elixir functions that spit out Orb instructions. Go another step and write macros that accept blocks and transform each Elixir expression. For example, this is how SilverOrb’s StringBuilder and XMLBuilder work under the hood.

## Dynamic compilation

Orb lets you run any Elixir code at compile-time. You could have dynamically enabled feature flags by reading from the `Process` dictionary. You could call out to any existing Elixir library for Hex. You could even make HTTP requests or talk to a database. Orb instructions are just data, so it doesn’t matter what process you use to make or inform that data.
