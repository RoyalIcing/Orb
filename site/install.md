# Installing Orb

First, [install Elixir](https://elixir-lang.org/install.html).

Create an Elixir project with say `mix new your_project_name`.

Add `orb` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:orb, "~> 0.0.41"}
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
```