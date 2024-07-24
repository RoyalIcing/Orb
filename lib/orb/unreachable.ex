defmodule Orb.Unreachable do
  @moduledoc false

  defstruct push_type: nil, debug_reason: nil

  defimpl Orb.ToWat do
    def to_wat(
          %Orb.Unreachable{},
          indent
        ) do
      [indent, "unreachable"]
    end
  end

  defimpl Orb.ToWasm do
    def to_wasm(%Orb.Unreachable{}, _context), do: [0x00]
  end
end
