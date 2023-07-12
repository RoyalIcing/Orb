defmodule Orb.Memory do
  defmacro pages(min_count) do
    quote do
      @wasm_memory unquote(min_count)
    end
  end

  defstruct name: "", min: 0, exported?: false

  def from(nil), do: nil
  def from([]), do: nil

  def from(list) when is_list(list) do
    case Enum.max(list) do
      0 ->
        nil

      min ->
        %__MODULE__{min: min}
    end
  end

  defimpl Orb.ToWat do
    def to_wat(%Orb.Memory{min: min}, indent) do
      [
        indent,
        ~S{(memory (export "memory")},
        case min do
          nil -> []
          int -> [" ", to_string(int)]
        end,
        ~S{)},
        "\n"
      ]
    end
  end
end
