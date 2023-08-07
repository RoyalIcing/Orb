defmodule Orb.CustomType do
  @callback wasm_type() :: :i32 | :i64 | :f32 | :f64
  @callback load_instruction() :: :load | :load8_s | :load8_u | :load16_s | :load16_u | :load32_s | :load32_u
  # TODO: remove byte_count
  @callback byte_count() :: 1 | 4 | 8

  @optional_callbacks load_instruction: 0
end
