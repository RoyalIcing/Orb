# Installing Orb

First, [install Elixir](https://elixir-lang.org/install.html) and create an Elixir project with say `mix new your_project_name`.

Add `orb` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:orb, "~> 0.2.2"}
  ]
end
```

Run `mix deps.get`.

You can now `use Orb` in your modules:

```elixir
defmodule Example do
  use Orb

  defw meaning_of_life(), I32 do
    42
  end
end

wasm_bytes = Orb.to_wasm(Example)
webassembly_text_format = Orb.to_wat(Example)
```

## Serving WebAssembly from Phoenix

Within a Phoenix or other Plug app you can send the WebAssembly bytes like so:

```elixir
defmodule MyController do
  def show(conn, _) do
    wasm_bytes = Orb.to_wasm(Example)

    conn
    |> put_resp_content_type("application/wasm", nil)
    |> send_resp(200, wasm_bytes)
  end
end
```