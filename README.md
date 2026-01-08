<p align="center">
  <img src="orb-logo-blue-orange.svg" alt="Orb logo" width="384" height="384">
</p>

<h1 align="center">Orb: Write Composable WebAssembly using Elixir</h1>

<p dir="ltr" align="center"><a href="https://hexdocs.pm/orb" rel="nofollow">Docs</a> | <a href="https://github.com/RoyalIcing/Orb/tree/main/examples">Examples</a></p>

<p dir="ltr" align="center"><a href="https://livebook.dev/run?url=https%3A%2F%2Fgithub.com%2FRoyalIcing%2FOrb%2Fblob%2Fmain%2Fexamples%2Ftemperature-converter.livemd" rel="nofollow"><img src="https://livebook.dev/badge/v1/black.svg" alt="Livebook: Temperature Converter"></a></p>

## Features

Write WebAssembly using Elixir as your compiler:

- Like how React’s JSX lets you run JavaScript that produces HTML documents, Orb lets you write Elixir that produces WebAssembly modules.
- Write using any WebAssembly 1.0 instructions.
- Produce tiny `.wasm` executables: **kilobytes not megabytes**. It has zero runtime overhead: define a function or global and that’s all that is compiled.
- Use Elixir **modules to organize and reuse** code, functions and **macros to create composable abstractions**, and chain function calls together with the **pipe `|>` operator**. Publish your code to [Hex](https://hex.pm).
- Run **any Elixir code at compile time** e.g. call out to an Elixir library, or make network requests, or integrate within an existing Elixir application — and have it influence what WebAssembly instructions are output.
- **Dynamically assemble modules on-the-fly** e.g. use feature flags to conditionally compile code paths, creating custom “tree shaken” WebAssembly modules.
- **Write automated tests** using [Elixir’s ExUnit](https://hexdocs.pm/ex_unit/ExUnit.html).
- Define your own custom WebAssembly instructions and abstractions that output to `wat` and `wasm` formats.

I think of it as like how React’s JSX lets you write dynamic HTML in JavaScript, Orb lets you write dynamic WebAssembly in Elixir.

- HTML document loaded by the browser running…
  - JavaScript loading…
    - React library rendering…
      - Your components producing…
        - HTML that then updates document

- HTML document loaded by the browser running…
  - JavaScript loading…
    - React library streaming…
      - Node.js running on server bundling…
        - Your server components producing…
          - JSX & references to client components
      - Server streamed output & client components rendering…
        - HTML that then updates document

- HTML document loaded by the browser running…
  - JavaScript loading…
    - WebAssembly module compiled from…
      - Elixir running on server assembling…
        - WebAssembly globals, functions, and memory
    - WebAssembly instance executing and producing…
        - HTML that then updates document

## Status

Orb is alpha in active development. My aim is to refine the current feature set and complete a `.wasm` compiler (current it compiles to WebAssembly’s `.wat` text format) in order to get to beta.

## Components

Components in Orb are deterministic functions with an explicit contract of inputs to output.

Component inputs can be encoded to a URL query. This make collaborating and debugging much easier — just share a URL.

Components can output numbers or an array of memory. They cannot produce side-effects.

## Contracts

```
#defw url_path_input(used: Str.Size) :: Str
#defw url_query_input(used: Str.Size) :: Str

region Input
region Output

defw get_input_range() :: Input.Range
defw get_query_keys() :: Output.Range
defw get_media_types() :: Output.Range

defw GET(query: Input.Range) :: {MediaType, Output.Range}
defw GET(path_and_query: Input.Str, headers: Input.Str) :: {MediaType, Output.Range}

defw POST(query: Input.Range, body: Input.Range) :: {MediaType, Output.Range}
```

## Testing

```sh
silk -I example.wasm
silk -X GET example.wasm
silk -i example.wasm
silk --data-urlencode "q=hello world" --data-urlencode "page=2" example.wasm

silk serve example.wasm --port 7777
silk image example.wasm -o still.png
```

## Anti-Features

The following are a list of things that Orb has chosen **not** to support:

- Execute any Elixir code at WebAssembly runtime. It’s not a goal of Orb to take any piece of everyday Elixir code and have it run in WebAssembly. However, because you can use macros you could decide to build that functionality on top of Orb.
- Access the DOM. I believe the DOM is a poor fit for WebAssembly with its big object graph requiring lots of communication between WebAssembly and its host. Instead we prefer things that serialize like HTML, SVG, XML, CSV.
- WASI support. It’s not stabilized yet and for now I’d rather it be a library built on top of Orb.
- Produce the most optimized code theoretically possible. Use `wasm-opt` if you really need to squeeze every byte possible from your final `.wasm` file. However, Orb does aim to produce slim `.wasm` files without unnecessary bloat like heavy runtimes.

## Libraries

- **Orb** (alpha): Write Core WebAssembly 1.0 in Elixir.
- [**SilverOrb**](https://github.com/RoyalIcing/SilverOrb) (work-in-progress): Batteries-included standard library for Orb.
- OrbExtismPDK (coming later): Write Extism plugins in Elixir with Orb.

## Installation

Add `orb` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:orb, "~> 0.2.2"}
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
wat = Orb.to_wat(CalculateMean)
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

Write this out as a `.wat` WebAssembly text file:

```elixir
File.write!("example.wat", wat)
```

You can then compile this to a `.wasm` WebAssembly file using [wat2wasm from the WebAssembly Binary Toolkit](https://github.com/WebAssembly/wabt):

```bash
wat2wasm example.wat
```

Or you can execute it directly in Elixir with [OrbWasmtime](https://github.com/RoyalIcing/OrbWasmtime):

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
