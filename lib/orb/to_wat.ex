defprotocol Orb.ToWat do
  @doc "Protocol for converting to WebAssembly text format (.wat)"
  def to_wat(data, indent)
end

defmodule Orb.ToWat.Error do
  defexception [:message, :exception]

  @impl Exception
  def exception(opts) do
    exception = Keyword.fetch!(opts, :exception)
    value = Keyword.fetch!(opts, :value)
    msg = Exception.message(exception) <> " | Source AST: #{inspect(value)}"
    %__MODULE__{message: msg, exception: exception}
  end
end

defmodule Orb.ToWat.Helpers do
  alias Orb.CustomType

  def do_type(type) do
    do_type(type, 0, type)
  end

  defp do_type(_type, 10, original_type) do
    raise "Cannot unfold deep 10+ layers of CustomType nesting. Top type is #{original_type}."
  end

  defp do_type(type, nesting, original_type) do
    case type do
      :i64 ->
        "i64"

      :i32 ->
        "i32"

      :f64 ->
        "f64"

      :f32 ->
        "f32"

      # e.g. {I32, I32} or {F32, F32, F32}
      tuple when is_tuple(tuple) ->
        tuple
        |> Tuple.to_list()
        |> Enum.map(&do_type/1)
        |> Enum.join(" ")

      type ->
        CustomType.resolve!(type) |> do_type(nesting + 1, original_type)
    end
  end
end
