![Orb logo](orb-logo-orange.svg)

# Orb: Write WebAssembly with the power of Elixir

Orb is a DSL for WebAssembly with the full power of the Elixir language:

- Function piping
- Break problems into smaller modules and compose them together
- Macros
- Share code with the Hex package manager

## Installation

The package can be installed via Hex by adding `orb` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:orb, "~> 0.0.5"}
  ]
end
```

## About

```elixir
defmodule CalculateMean do
  use Orb

  I32.global(
    count: 0,
    tally: 0
  )

  wasm do
    func insert(element: I32) do
      @count = @count + 1
      @tally = @tally + element
    end

    func calculate_mean(), I32 do
      @tally / @count
    end
  end
end

Orb.to_wat(CalculateMean)
# """
# (module $CalculateMean
#   (global $count (mut i32) (i32.const 0))
#   (global $tally (mut i32) (i32.const 0))
#   (func $insert (export "insert") (param $element i32)
#     (i32.add (global.get $count) (i32.const 1))
#     (global.set $count)
#     (i32.add (global.get $tally) (local.get $element))
#     (global.set $tally)
#   )
#   (func $calculate_mean (export "calculate_mean") (result i32)
#     (i32.div_s (global.get $tally) (global.get $count))
#   )
# )
# """
```

Run with [OrbWasmtime](https://github.com/RoyalIcing/OrbWasmtime):

```elixir
alias OrbWasmtime.Instance

# Run above example
inst = Instance.run(CalculateMean)
Instance.call(inst, :insert, 4)
Instance.call(inst, :insert, 5)
Instance.call(inst, :insert, 6)
assert Instance.call(inst, :calculate_mean) == 5
```

## Project Goals

- Write a HTML component and run it in:
    - Phoenix LiveView & dead views
    - In the browser using `<wasm-html>` custom element
- State machines
- Parsers
- Formatters & string builders
- Code generators

## Why develop Orb in Elixir?

Here are the reasons I chose to write Orb in Elixir.

- Established language:
    - Has package manager
    - Has language server with autocomplete
    - Has documentation system
    - Has unit test library
    - Has CI integration
    - Has linting
    - Has upcoming type system
- Established frameworks:
    - Can integrate with Phoenix LiveView
    - Can connect to cloud, databases
    - Can integrate with Rust
- Community that is friendly
- Can be extended with additional functions and macros

----

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/orb>.
