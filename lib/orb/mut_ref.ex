defmodule Orb.MutRef do
  @moduledoc """
  Use `Orb.DSL.mut!/1` to get a mutable reference to a global or local.
  """

  defstruct [:read, :write, :type]

  def from(%Orb.VariableReference{} = read) do
    %__MODULE__{read: read, write: Orb.VariableReference.as_set(read), type: read.type}
  end

  def store(%__MODULE__{write: write}, value) do
    # TODO: Use InstructionSequence
    [value, write]
  end
end
