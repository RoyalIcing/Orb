defmodule Orb.TypeCheckError do
  defexception [:expected_type, :received_type, :message]

  defp make_message(expected_type, received_type) do
    "Expected type #{expected_type}, found #{received_type}."
  end

  @impl Exception
  def exception(opts) do
    expected_type = Keyword.fetch!(opts, :expected_type)
    received_type = Keyword.fetch!(opts, :received_type)
    msg = make_message(expected_type, received_type)
    %__MODULE__{expected_type: expected_type, received_type: received_type, message: msg}
  end
end
