defprotocol Orb.TypeNarrowable do
  @doc "Protocol for narrowing types e.g. from Elixir.Integer to I32."
  @fallback_to_any true
  def type_narrow_to(node, narrower_type)
end

defimpl Orb.TypeNarrowable, for: Any do
  def type_narrow_to(node, _), do: node
end

defimpl Orb.TypeNarrowable, for: Integer do
  def type_narrow_to(i, narrower_type) do
    case Orb.Ops.to_primitive_type(narrower_type) do
      :i64 ->
        Orb.Instruction.wrap_constant!(:i64, i)

      :i32 ->
        Orb.Instruction.wrap_constant!(:i32, i)

      _ ->
        i
    end
  end
end
