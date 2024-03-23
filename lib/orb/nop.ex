defmodule Orb.Nop do
  @moduledoc false

  defstruct push_type: nil, debug_reason: nil

  defimpl Orb.ToWat do
    def to_wat(%Orb.Nop{}, indent) do
      [indent, "nop"]
    end
  end
end
