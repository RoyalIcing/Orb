defmodule Orb.Control.Return do
  @moduledoc false

  defstruct body: :unset, push_type: nil

  def new(), do: %__MODULE__{body: nil}
  def new(value), do: %__MODULE__{body: value}

  defimpl Orb.ToWat do
    alias Orb.ToWat.Instructions

    def to_wat(
          %Orb.Control.Return{body: nil},
          indent
        ) do
      [indent, "return"]
    end

    def to_wat(
          %Orb.Control.Return{body: value},
          indent
        ) do
      [
        indent,
        "(",
        "return ",
        Instructions.do_wat(value),
        ")"
      ]
    end
  end

  defimpl Orb.ToWasm do
    def to_wasm(%Orb.Control.Return{body: nil}, _), do: [0x0F]

    def to_wasm(%Orb.Control.Return{body: value}, context) do
      [
        Orb.ToWasm.to_wasm(value, context),
        0x0F
      ]
    end
  end
end
