defprotocol Orb.TypeNarrowable do
  @doc "Protocol for narrowing types e.g. from Elixir.Integer to I32."
  @fallback_to_any true
  def type_narrow_to(node, narrower_type)
end

defimpl Orb.TypeNarrowable, for: Any do
  def type_narrow_to(node, _), do: node
end
