defmodule Orb.Ops do
  @moduledoc false

  # See: https://webassembly.github.io/spec/core/syntax/instructions.html#numeric-instructions
  @i_unary_ops ~w(clz ctz popcnt)a
  @i_binary_ops ~w(add sub mul div_u div_s rem_u rem_s and or xor shl shr_u shr_s rotl rotr)a
  @i_test_ops ~w(eqz)a
  @i_relative_ops ~w(eq ne lt_u lt_s gt_u gt_s le_u le_s ge_u ge_s)a
  # https://developer.mozilla.org/en-US/docs/WebAssembly/Reference/Numeric/Wrap
  @i32_wrap_ops ~w(wrap_i64)a
  # https://developer.mozilla.org/en-US/docs/WebAssembly/Reference/Numeric/Extend
  @i64_extend_ops ~w(extend_i32_s extend_i32_u)a
  # https://developer.mozilla.org/en-US/docs/WebAssembly/Reference/Memory/Load
  @i32_load_ops ~w(load load8_u load8_s load16_s load16_u)a
  @i64_load_ops @i32_load_ops ++ ~w(load32_s load32_u)a
  # https://developer.mozilla.org/en-US/docs/WebAssembly/Reference/Memory/Store
  @i32_store_ops ~w(store store8 store16)a
  @i64_store_ops @i32_store_ops ++ ~w(store32)a

  # https://developer.mozilla.org/en-US/docs/WebAssembly/Reference/Numeric/Truncate_float_to_int
  @i_trunc_ops ~w(trunc_f32_s trunc_f32_u trunc_f64_s trunc_f64_u)a

  @i32_ops_1 @i_unary_ops ++ @i_test_ops ++ @i_trunc_ops ++ @i32_wrap_ops
  @i32_ops_2 @i_binary_ops ++ @i_relative_ops
  @i32_ops_all @i32_ops_1 ++ @i32_ops_2 ++ @i32_load_ops ++ @i32_store_ops

  @i64_ops_1 @i_unary_ops ++ @i_test_ops ++ @i_trunc_ops ++ @i64_extend_ops
  @i64_ops_2 @i_binary_ops ++ @i_relative_ops
  @i64_ops_all @i64_ops_1 ++ @i64_ops_2 ++ @i64_load_ops ++ @i64_store_ops

  @f32_ops_1 ~w(floor ceil trunc nearest abs neg sqrt convert_i32_s convert_i32_u)a
  @f32_ops_2 ~w(add sub mul div eq ne lt gt le ge copysign min max)a

  # TODO: add conversions ops https://developer.mozilla.org/en-US/docs/WebAssembly/Reference/Numeric#conversion

  @integer_types ~w(i64 i32)a
  @float_types ~w(f64 f32)a
  @primitive_types @integer_types ++ @float_types
  defguard is_primitive_type(type) when type in [:i64, :i32, :i32_u8, :f32]

  defp lowest_type(:i64), do: :i64
  defp lowest_type(:i32), do: :i32
  defp lowest_type(:i32_u8), do: :i32
  defp lowest_type(:f32), do: :f32

  def to_primitive_type(type) when is_primitive_type(type), do: type
  def to_primitive_type(:unknown_effect), do: :unknown_effect
  def to_primitive_type(mod) when is_atom(mod) do
    Code.ensure_loaded!(mod)
    to_primitive_type(mod.wasm_type())
  end

  def types_compatible?(Elixir.Integer, b),
    do: to_primitive_type(b) in @integer_types

  def types_compatible?(a, Elixir.Integer),
    do: to_primitive_type(a) in @integer_types

  def types_compatible?(Elixir.Float, b),
    do: to_primitive_type(b) in @float_types

  def types_compatible?(a, Elixir.Float),
    do: to_primitive_type(a) in @float_types

  def types_compatible?(a, b),
    do: lowest_type(to_primitive_type(a)) === lowest_type(to_primitive_type(b))

  def extract_type(n) when is_integer(n), do: Elixir.Integer
  def extract_type(n) when is_float(n), do: Elixir.Float
  def extract_type(%{type: :i32}), do: :i32
  def extract_type(%{type: type}), do: to_primitive_type(type)

  def extract_common_type(a, b) do
    case {extract_type(a), extract_type(b)} do
      {same, same} -> same
      {type, Elixir.Integer} when type in @integer_types -> type
      {Elixir.Integer, type} when type in @integer_types -> type
      {type, Elixir.Float} when type in @float_types -> type
      {Elixir.Float, type} when type in @float_types -> type
      _ -> nil
    end
  end

  defmacro i32(arity_or_type)
  defmacro i32(1), do: @i32_ops_1 |> Macro.escape()
  defmacro i32(2), do: @i32_ops_2 |> Macro.escape()
  defmacro i32(:load), do: @i32_load_ops |> Macro.escape()
  defmacro i32(:store), do: @i32_store_ops |> Macro.escape()
  defmacro i32(:all), do: @i32_ops_all |> Macro.escape()

  defmacro i64(arity_or_type)
  defmacro i64(1), do: @i64_ops_1 |> Macro.escape()
  defmacro i64(2), do: @i64_ops_2 |> Macro.escape()
  defmacro i64(:load), do: @i64_load_ops |> Macro.escape()
  defmacro i64(:store), do: @i64_store_ops |> Macro.escape()
  defmacro i64(:all), do: @i64_ops_all |> Macro.escape()

  defmacro f32(arity_or_type)
  defmacro f32(1), do: @f32_ops_1 |> Macro.escape()
  defmacro f32(2), do: @f32_ops_2 |> Macro.escape()

  defp i32_arity(op) when op in @i32_ops_1, do: 1
  defp i32_arity(op) when op in @i32_ops_2, do: 2
  defp i64_arity(op) when op in @i64_ops_1, do: 1
  defp i64_arity(op) when op in @i64_ops_2, do: 2
  defp f32_arity(op) when op in @f32_ops_1, do: 1
  defp f32_arity(op) when op in @f32_ops_2, do: 2

  defp i32_param_type(:const, 0), do: Elixir.Integer
  defp i32_param_type(op, 0) when op in @i32_load_ops, do: :i32
  defp i32_param_type(op, i) when op in @i32_store_ops and i in [0, 1], do: :i32
  defp i32_param_type(op, 0) when op in @i_trunc_ops, do: :f32
  defp i32_param_type(op, 0) when op in @i_unary_ops, do: :i32
  defp i32_param_type(op, 0) when op in @i_test_ops, do: :i32
  defp i32_param_type(op, 0) when op in @i32_wrap_ops, do: :i64
  defp i32_param_type(op, i) when op in @i_binary_ops and i in [0, 1], do: :i32
  defp i32_param_type(op, i) when op in @i_relative_ops and i in [0, 1], do: :i32
  defp i32_param_type(_op, _param_index), do: :error

  defp i64_param_type(:const, 0), do: Elixir.Integer
  defp i64_param_type(op, 0) when op in @i64_load_ops, do: :i64
  defp i64_param_type(op, i) when op in @i64_store_ops and i in [0, 1], do: :i64
  defp i64_param_type(op, 0) when op in @i_trunc_ops, do: :f64
  defp i64_param_type(op, 0) when op in @i_unary_ops, do: :i64
  defp i64_param_type(op, 0) when op in @i_test_ops, do: :i64
  defp i64_param_type(op, 0) when op in @i64_extend_ops, do: :i32
  defp i64_param_type(op, i) when op in @i_binary_ops and i in [0, 1], do: :i64
  defp i64_param_type(op, i) when op in @i_relative_ops and i in [0, 1], do: :i64
  defp i64_param_type(_op, _param_index), do: :error

  defp f32_param_type(:const, 0), do: Elixir.Float
  defp f32_param_type(op, 0) when op in @f32_ops_1, do: :f32
  defp f32_param_type(op, i) when op in @f32_ops_2 and i in [0, 1], do: :f32
  defp f32_param_type(_op, _param_index), do: :error

  def i32_param_type!(op, param_index) do
    case i32_param_type(op, param_index) do
      :error ->
        arity = i32_arity(op)

        raise ArgumentError,
              "WebAssembly instruction i32.#{op}/#{arity} does not accept a #{nth(param_index)} argument."

      type ->
        type
    end
  end

  def i64_param_type!(op, param_index) do
    case i64_param_type(op, param_index) do
      :error ->
        arity = i64_arity(op)

        raise ArgumentError,
              "WebAssembly instruction i64.#{op}/#{arity} does not accept a #{nth(param_index)} argument."

      type ->
        type
    end
  end

  def f32_param_type!(op, param_index) do
    case f32_param_type(op, param_index) do
      :error ->
        arity = f32_arity(op)

        raise ArgumentError,
              "WebAssembly instruction f32.#{op}/#{arity} does not accept a #{nth(param_index)} argument."

      type ->
        type
    end
  end

  def param_type!(:i32, op, param_index), do: i32_param_type!(op, param_index)
  def param_type!(:i64, op, param_index), do: i64_param_type!(op, param_index)
  def param_type!(:f32, op, param_index), do: f32_param_type!(op, param_index)

  defp nth(0), do: "1st"
  defp nth(1), do: "2nd"
  defp nth(2), do: "3rd"
  defp nth(n), do: "#{n + 1}th"
end
