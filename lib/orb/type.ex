defmodule Orb.Type do
  @callback wasm_type() :: :i32 | :f32
  @callback byte_count() :: 1 | 4
end
