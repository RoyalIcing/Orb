defmodule Orb.Type do
  @callback wasm_type() :: :i32 | :i64 | :f32 | :f64
  @callback byte_count() :: 1 | 4 | 8
end
