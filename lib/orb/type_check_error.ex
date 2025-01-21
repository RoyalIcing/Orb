defmodule Orb.TypeCheckError do
  defexception [:expected_type, :received_type, :instruction_identifier, :message]

  alias require Orb.Ops

  defp make_message(type_a, type_b, :if) do
    "if/else expected consistent clause types, if: #{format_type(type_a)}, but else: #{format_type(type_b)}."
  end

  defp make_message(expected_type, received_type, instruction_identifier)
       when is_binary(instruction_identifier) do
    "Instruction #{instruction_identifier} expected type #{format_type(expected_type)}, found #{format_type(received_type)}."
  end

  defp format_type(type) when Ops.is_primitive_type(type), do: inspect(type)
  defp format_type(:unknown_effect), do: "unknown_effect"
  defp format_type(Elixir.Integer), do: "Elixir.Integer"
  defp format_type(Elixir.Float), do: "Elixir.Float"

  defp format_type(type) when is_atom(type),
    do: "#{inspect(Ops.to_primitive_type(type))} via #{inspect(type)}"

  defp format_type(type) when is_binary(type), do: type

  @impl Exception
  def exception(opts) do
    expected_type = Keyword.fetch!(opts, :expected_type)
    received_type = Keyword.fetch!(opts, :received_type)
    instruction_identifier = Keyword.fetch!(opts, :instruction_identifier)
    msg = make_message(expected_type, received_type, instruction_identifier)

    %__MODULE__{
      expected_type: expected_type,
      received_type: received_type,
      instruction_identifier: instruction_identifier,
      message: msg
    }
  end
end
