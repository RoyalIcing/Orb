# Installing Orb

Create an Elixir project with say `mix new your_project_name`.

Add `orb` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:orb, "~> 0.0.39"}
  ]
end
```

Run `mix deps.get`.

You can now `use Orb` in your modules:

```elixir
defmodule Example do
    use Orb

end
```