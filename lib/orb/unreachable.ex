defmodule Orb.Unreachable do
  @moduledoc false

  defstruct debug_reason: nil

  defimpl Orb.ToWat do
    def to_wat(
          %Orb.Unreachable{},
          indent
        ) do
      [indent, "unreachable"]
    end
  end
end
