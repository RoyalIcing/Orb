defmodule Orb.Control.Return do
  defstruct body: :unset

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
end
