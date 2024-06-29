defmodule Orb.Instruction.Const do
  @moduledoc false
  defstruct [:push_type, :value]

  def new(push_type, value) when push_type in ~w(i32 i64 f32 f64)a do
    %__MODULE__{push_type: push_type, value: value}
  end

  defimpl Orb.ToWat do
    def to_wat(%Orb.Instruction.Const{push_type: push_type, value: value}, indent) do
      [
        indent,
        ["(", Atom.to_string(push_type), ".const "],
        to_string(value),
        ")"
      ]
    end
  end
end
