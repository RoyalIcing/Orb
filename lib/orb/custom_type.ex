defmodule Orb.CustomType do
  @moduledoc """
  Define custom types composed of other types. Your type can then be passed as parameters or result types.

  Composite types (tuples) are not supported as locals currently, as locals can only be primitive types.

  ```elixir
  defmodule RGB do
    @behaviour Orb.CustomType
    @impl Orb.CustomType
    def wasm_type, do: {:f32, :f32, :f32}
    
    # TODO: allow naming each element:
    # def wasm_type, do: [r: :f32, g: :f32, b: :f32]
  end
  ```
  """

  @type wasm_primitive() :: :i64 | :i32 | :f64 | :f32
  @callback wasm_type() ::
              wasm_primitive()
              | {wasm_primitive(), wasm_primitive()}
              | {wasm_primitive(), wasm_primitive(), wasm_primitive()}
              | {wasm_primitive(), wasm_primitive(), wasm_primitive(), wasm_primitive()}
  @callback type_name() :: atom()
  @callback load_instruction() ::
              :load | :load8_s | :load8_u | :load16_s | :load16_u | :load32_s | :load32_u
  # @callback store_instruction() :: :store | :store8 | :store16 | :store32

  @optional_callbacks type_name: 0, load_instruction: 0

  defmodule InvalidError do
    defexception [:mod, :message]

    defp make_message(mod) do
      "You passed a Orb type module #{mod} that does not implement wasm_type/0."
    end

    @impl Exception
    def exception(opts) do
      mod = Keyword.fetch!(opts, :mod)
      msg = make_message(mod)

      %__MODULE__{
        mod: mod,
        message: msg
      }
    end
  end

  # TODO: remove
  # def resolve!(:nop), do: nil
  # def resolve!(:unknown_effect), do: nil
  def resolve!(nil), do: raise("Invalid custom type nil")

  def resolve!(mod) do
    Code.ensure_loaded!(mod)

    if function_exported?(mod, :wasm_type, 0) do
      mod.wasm_type()
    else
      raise InvalidError, mod: mod
    end
  end
end
