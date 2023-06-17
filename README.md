# Orb: Write WebAssembly in Elixir, run it anywhere

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `orb` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:orb, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/orb>.

## Project Goals

- Write a HTML component and run it in:
    - Phoenix LiveView & dead views
    - In the browser using `<wasm-html>` custom element
- State machines
- Parsers
- Formatters & string builders
