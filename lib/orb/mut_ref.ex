defmodule Orb.MutRef do
  @moduledoc """
  Use `Orb.mut!/1` to get a mutable reference to a global or local.
  """

  defstruct [:read, :write, :type]

  def from(%Orb.VariableReference{} = read) do
    %__MODULE__{read: read, write: Orb.VariableReference.as_set(read), type: read.type}
  end

  def from({:global_get, name} = read) do
    %__MODULE__{read: read, write: {:global_set, name}}
  end

  def from({:local_get, name} = read) do
    %__MODULE__{read: read, write: {:local_set, name}}
  end

  def store(%__MODULE__{write: write}, value) do
    [value, write]
  end
end