<p align="center">
  <img src="orb-logo-blue-orange.svg" alt="Orb logo" width="384" height="384">
</p>

<h1 align="center">Orb: Write WebAssembly with Elixir</h1>

<p dir="ltr" align="center"><a href="https://hexdocs.pm/orb" rel="nofollow">Docs</a> | <a href="https://github.com/RoyalIcing/Orb/tree/main/examples">Examples</a></p>

<p dir="ltr" align="center"><a href="https://livebook.dev/run?url=https%3A%2F%2Fgithub.com%2FRoyalIcing%2FOrb%2Fblob%2Fmain%2Fexamples%2Ftemperature-converter.livemd" rel="nofollow"><img src="https://livebook.dev/badge/v1/black.svg" alt="Livebook: Temperature Converter"></a></p>

Write WebAssembly with the power of Elixir as your compiler:

- Use Elixir’s **module system** to break problems down and then compose them together.
- Chain function calls together with the **pipe `|>` operator**.
- Publish reusable code with the [**Hex package manager**](https://hex.pm).
- **Write unit tests** using [Elixir’s built-in ExUnit](https://hexdocs.pm/ex_unit/ExUnit.html).
- Reduce boilerplate with Elixir’s **powerful macro system**.
- **Run dynamic Elixir code at compile time** e.g. talk to the rest of your Elixir application, call out to an Elixir library, or make network requests.
- **Compile modules on-the-fly** e.g. use feature flags to conditionally compile code paths or enable particular WebAssembly instructions, creating a custom “tree shaken” WebAssembly module per user.

## Installation

Add `orb` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:orb, "~> 0.0.35"}
  ]
end
```

## Example

```elixir
defmodule CalculateMean do
  use Orb

  global do
    @tally 0
    @count 0
  end

  defw insert(n: I32) do
    @tally = @tally + n
    @count = @count + 1
  end

  defw calculate_mean(), I32 do
    @tally / @count
  end
end
```

This can be converted to WebAssembly text format (wat):

```elixir
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

You can then execute it in Elixir with [OrbWasmtime](https://github.com/RoyalIcing/OrbWasmtime):

```elixir
alias OrbWasmtime.Instance

# Run above example
inst = Instance.run(CalculateMean)
Instance.call(inst, :insert, 4)
Instance.call(inst, :insert, 5)
Instance.call(inst, :insert, 6)
assert Instance.call(inst, :calculate_mean) == 5
```

Note there is [another excellent Elixir Wasmtime wrapper out there called Wasmex](https://github.com/tessi/wasmex), you may want to check that out too.

## Composing modules

You can compose modules together using `Orb.include/1`:

```elixir
defmodule Math do
  use Orb

  defw square(n: I32), I32 do
    n * n
  end
end

defmodule SomeOtherModule do
  use Orb

  Orb.include(Math)

  defw magic(), I32 do
    Math.square(3)
  end
end
```

## Use cases

- Parsers
- State machines
- Formatters & string builders
- HTTP endpoint that can be deployed agnostically to the server or edge.
- Interactive UI controls
- Write a HTML component and run it in:
    - Phoenix LiveView & dead views
    - In the browser using `<wasm-html>` custom element
- LiveView and its server rendering is a fantastic default, but the latency can be noticeable for certain UI interactions. With Orb you could use Elixir to write a WebAssembly module that then runs in the user’s browser.
- Animation that runs fast in the browser and also works on the server
- Code generators

## Why WebAssembly?

- It runs on all of today’s major platforms: browser, server, edge, mobile, laptop, tablet, desktop.
- Universal/isomorphic components (ones that run on the server and browser) are possible in React and Next.js, but they have many different flavours and can get pretty complex for a system that was meant to be declarative.
- Like HTML and CSS it’s backwards compatible, which means WebAssembly you author today will be guaranteed to still work in a decade or longer.
- It’s memory-safe and sandboxed. It can’t read memory outside of itself, only what has been explicitly passed into it. It can even be timeboxed to run for a maximum duration.
- It’s fast.

## Why develop Orb in Elixir?

Here are the reasons I chose to write Orb in Elixir.

- Established language:
    - Has package manager.
    - Has composable modules with `alias` & `use`.
    - Has syntax highlighting in IDEs, GitHub, and in highlighting libraries.
    - Has language server with autocomplete.
    - Has documentation system.
    - Has unit test library.
    - Has CI integration.
    - Has linting.
    - Integrates with native libraries in Rust and Zig.
    - Has upcoming type system.
- Established frameworks:
    - Can integrate with Phoenix LiveView.
    - Can connect to cloud, databases.
    - Can integrate with Rust.
- Community that is friendly and collaborative.
- Can be extended with additional functions and macros:
  - Unlike say C’s basic string-inserting preprocessor, Elixir is a full programming language without constraints.
  - We can read files or the network and then generate code.
  - You can create your own DSL. Want to enforce immutable-style programming? Want to add pattern matching? Design your own DSL on top of Orb for it.
