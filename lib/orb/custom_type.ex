defmodule Orb.CustomType do
  @callback wasm_type() :: :i64 | :i32 | :f64 | :f32
  @callback load_instruction() :: :load | :load8_s | :load8_u | :load16_s | :load16_u | :load32_s | :load32_u
  # TODO: remove byte_count
  @callback byte_count() :: 1 | 4 | 8

  @optional_callbacks load_instruction: 0

  def resolve!(mod) do
    Code.ensure_loaded!(mod)

    if function_exported?(mod, :wasm_type, 0) do
      mod.wasm_type()
    else
      raise "You passed a Orb type module #{mod} that does not implement wasm_type/0."
    end
  end
end
