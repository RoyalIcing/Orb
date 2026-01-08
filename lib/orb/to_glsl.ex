defprotocol Orb.ToGLSL do
  @doc "Protocol for converting to WebGL2 shader GLSL format"
  def to_glsl(data, context)
end

defmodule Orb.ToGLSL.Context do
  @moduledoc """
  Context for managing GLSL compilation.
  """
  defstruct todo: %{}

  def new(), do: %__MODULE__{}
end

defmodule Orb.ToGLSL.Error do
  defexception [:message, :exception]

  @impl Exception
  def exception(opts) do
    exception = Keyword.fetch!(opts, :exception)
    value = Keyword.fetch!(opts, :value)
    msg = Exception.message(exception) <> " | Source AST: #{inspect(value)}"
    %__MODULE__{message: msg, exception: exception}
  end
end

defmodule Orb.ToGLSL.Helpers do
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
        raise "Unsupported type: i64"

      :i32 ->
        raise "Unsupported type: i32"

      :f64 ->
        raise "Unsupported type: f64"

      :f32 ->
        "float"

      {:f32, :f32} ->
        "vec2"

      {:f32, :f32, :f32} ->
        "vec3"

      {:f32, :f32, :f32, :f32} ->
        "vec4"

      # e.g. {I32, I32} or {F32, F32, F32}
      tuple when is_tuple(tuple) ->
        raise "Tuple types are unsupported"

      type ->
        CustomType.resolve!(type) |> do_type(nesting + 1, original_type)
    end
  end
end
