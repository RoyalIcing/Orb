# Custom Types

You can define custom types with the `Orb.CustomType` behaviour.

You implement the `wasm_type()` function and return one of `:i32`, `:i64`, `:f32` or `:f64`.

Even built-in types like `Orb.I64` are defined using custom types:

```elixir
defmodule Orb.I64 do
  @behaviour Orb.CustomType

  @impl Orb.CustomType
  def wasm_type(), do: :i64
end
```

## Function parameters

These custom types can be used as function parameters.

```elixir
defmodule Digit do
  @behaviour Orb.CustomType

  @impl Orb.CustomType
  def wasm_type(), do: :i32

  defw add(a: Digit, b: Digit), Digit do
    a + b
  end
end
```

This compiles to the exact same code as:

```elixir
defmodule Digit do
  defw add(a: :i32, b: :i32), :i32 do
    a + b
  end
end
```

## Memory offsets

If your module needs to work with pointers (memory offsets), we recommend defining a `:i32` custom type for it:

```elixir
defmodule MyLinkedList do
  @behaviour Orb.CustomType

  @impl Orb.CustomType
  def wasm_type(), do: :i32
end
```
