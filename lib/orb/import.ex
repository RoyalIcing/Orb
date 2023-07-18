defmodule Orb.Import do
  @moduledoc false

  defstruct [:module, :name, :type]

  defimpl Orb.ToWat do
    alias Orb.ToWat.Instructions

    def to_wat(%Orb.Import{module: nil, name: name, type: type}, indent) do
      ~s[#{indent}(import "#{name}" #{Instructions.do_wat(type)})]
    end

    def to_wat(%Orb.Import{module: module, name: name, type: type}, indent) do
      ~s[#{indent}(import "#{module}" "#{name}" #{Instructions.do_wat(type)})]
    end
  end
end
