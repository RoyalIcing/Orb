defmodule Orb.TypeCheckError do
  defexception [:expected_type, :received_type, :message]

  require Orb.Ops, as: Ops

  defp make_message(expected_type, received_type) do
    "Expected type #{format_type(expected_type)}, found #{format_type(received_type)}."
  end

  defp format_type(type) when Ops.is_primitive_type(type), do: to_string(type)
  defp format_type(type) when is_atom(type), do: "#{Ops.to_primitive_type(type)} via #{inspect(type)}"
  defp format_type(type) when is_binary(type), do: type

  @impl Exception
  def exception(opts) do
    expected_type = Keyword.fetch!(opts, :expected_type)
    received_type = Keyword.fetch!(opts, :received_type)
    msg = make_message(expected_type, received_type)
    %__MODULE__{expected_type: expected_type, received_type: received_type, message: msg}
  end
end
