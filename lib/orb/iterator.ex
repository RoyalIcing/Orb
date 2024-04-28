defmodule Orb.Iterator do
  # def fetch(%Orb.VariableReference{} = var, :valid?), do: {:ok, Orb.I32.le_u(var, ?z)}
  # def fetch(%Orb.VariableReference{} = var, :value), do: {:ok, var}
  # def fetch(%Orb.VariableReference{} = var, :next), do: {:ok, Orb.I32.add(var, 1)}

  @type var_ref :: %Orb.VariableReference{}

  @doc """
  Calculates whether the iterator is done or not.
  """
  @callback valid?(var_ref) :: %Orb.Instruction{} | integer()

  @doc """
  Extracts or calculates the current value.
  """
  @callback value(var_ref) :: %Orb.Instruction{} | integer() | float()

  @doc """
  Mutates the iterator advancing it to the next element.
  """
  @callback next(var_ref) :: %Orb.Instruction{} | integer() | float()
end
