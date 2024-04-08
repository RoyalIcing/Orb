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

  @f32_ops_1 ~w(floor ceil trunc nearest abs neg sqrt convert_i32_s convert_i32_u demote_f64)a
  @f32_ops_2 ~w(add sub mul div eq ne lt gt le ge copysign min max)a

  @f64_ops_1 ~w(floor ceil trunc nearest abs neg sqrt convert_i32_s convert_i32_u convert_i64_s convert_i64_u promote_f32)a
  @f64_ops_2 ~w(add sub mul div eq ne lt gt le ge copysign min max)a

  # TODO: add conversions ops https://developer.mozilla.org/en-US/docs/WebAssembly/Reference/Numeric#conversion

  @integer_types ~w(i64 i32)a
  @float_types ~w(f64 f32)a
  @primitive_types @integer_types ++ @float_types
  @effects ~w(unknown_effect memory_effect global_effect local_effect)a
  @elixir_types [Elixir.Integer, Elixir.Float]
  # @base_types @primitive_types ++ @effects ++ @elixir_types

  defguard is_primitive_type(type) when type in @primitive_types
  defguard is_primitive_integer_type(type) when type in @integer_types
  defguard is_primitive_float_type(type) when type in @float_types
  defguard is_effect(type) when type in @effects

  def to_primitive_type(type) when is_primitive_type(type), do: type
  def to_primitive_type(type) when is_effect(type), do: type
  def to_primitive_type(type) when type in @elixir_types, do: type
  # TODO: remove these as they don’t match is_primitive_type/1 above
  def to_primitive_type(nil), do: :nop
  def to_primitive_type(:nop), do: :nop
  def to_primitive_type(:trap), do: :trap
  def to_primitive_type(%{result: result}), do: result

  def to_primitive_type(type) when is_tuple(type) do
    for nested <- Tuple.to_list(type) do
      to_primitive_type(nested)
    end
    |> List.to_tuple()
  end

  def to_primitive_type(mod) when is_atom(mod) do
    Orb.CustomType.resolve!(mod) |> to_primitive_type()
  end

  def type_stack_count(type) when is_primitive_type(type), do: 1
  def type_stack_count(type) when is_effect(type), do: 0
  def type_stack_count(type) when is_atom(type), do: 1
  def type_stack_count(type) when is_tuple(type), do: tuple_size(type)

  def types_compatible?(Elixir.Integer, b),
    do: to_primitive_type(b) in @integer_types

  def types_compatible?(a, Elixir.Integer),
    do: to_primitive_type(a) in @integer_types

  def types_compatible?(Elixir.Float, b),
    do: to_primitive_type(b) in @float_types

  def types_compatible?(a, Elixir.Float),
    do: to_primitive_type(a) in @float_types

  def types_compatible?(a, b),
    do: to_primitive_type(a) === to_primitive_type(b)

  def typeof(n) when is_integer(n), do: Elixir.Integer
  def typeof(n) when is_float(n), do: Elixir.Float
  def typeof(%{push_type: type}), do: type
  def typeof(%{type_signature: type_signature}), do: %{type_signature: type_signature}
  def typeof(%{if: _}), do: :control
  def typeof(str) when is_binary(str), do: :i32
  # def typeof(_), do: :unknown_effect

  def typeof(value, :primitive), do: typeof(value) |> to_primitive_type()

  @spec pop_push_of(binary() | number() | map()) :: {any(), any()}
  def pop_push_of(n) when is_integer(n), do: {nil, Elixir.Integer}
  def pop_push_of(n) when is_float(n), do: {nil, Elixir.Float}
  def pop_push_of(%{pop_type: pop_type, push_type: push_type}), do: {pop_type, push_type}
  def pop_push_of(%{push_type: push_type}), do: {nil, push_type}
  # Orb.Loop.Branch, Orb.Block.Branch
  # Probably should add a `control: :branch`, `control: :return` field.
  def pop_push_of(%{if: _}), do: {nil, nil}
  # TODO: String64
  def pop_push_of(str) when is_binary(str), do: {nil, Process.get(Orb.StringConstantType, :i32)}

  def extract_common_type(a, b) do
    {nil, push_a} = pop_push_of(a)
    {nil, push_b} = pop_push_of(b)

    case {to_primitive_type(push_a), to_primitive_type(push_b)} do
      {same, same} -> same
      {a, b} when is_effect(a) and is_effect(b) -> nil
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

  # FIXME: conditional ops like i64.eq and i64.ge_u return i32 not i64
  defmacro i64(arity_or_type)
  defmacro i64(1), do: @i64_ops_1 |> Macro.escape()
  defmacro i64(2), do: @i64_ops_2 |> Macro.escape()
  defmacro i64(:load), do: @i64_load_ops |> Macro.escape()
  defmacro i64(:store), do: @i64_store_ops |> Macro.escape()
  defmacro i64(:all), do: @i64_ops_all |> Macro.escape()

  defmacro f32(arity_or_type)
  defmacro f32(1), do: @f32_ops_1 |> Macro.escape()
  defmacro f32(2), do: @f32_ops_2 |> Macro.escape()

  defmacro f64(arity_or_type)
  defmacro f64(1), do: @f64_ops_1 |> Macro.escape()
  defmacro f64(2), do: @f64_ops_2 |> Macro.escape()

  defp i32_arity(op) when op in @i32_ops_1, do: 1
  defp i32_arity(op) when op in @i32_ops_2, do: 2
  defp i64_arity(op) when op in @i64_ops_1, do: 1
  defp i64_arity(op) when op in @i64_ops_2, do: 2
  defp f32_arity(op) when op in @f32_ops_1, do: 1
  defp f32_arity(op) when op in @f32_ops_2, do: 2
  defp f64_arity(op) when op in @f64_ops_1, do: 1
  defp f64_arity(op) when op in @f64_ops_2, do: 2

  defp i32_param_type(op, param_index)
  defp i32_param_type(:const, 0), do: Elixir.Integer
  defp i32_param_type(op, 0) when op in @i32_load_ops, do: :i32
  defp i32_param_type(op, i) when op in @i32_store_ops and i in [0, 1], do: :i32
  defp i32_param_type(op, 0) when op in @i_trunc_ops, do: :f32
  defp i32_param_type(op, 0) when op in @i_unary_ops, do: :i32
  defp i32_param_type(op, 0) when op in @i_test_ops, do: :i32
  defp i32_param_type(op, 0) when op in @i32_wrap_ops, do: :i64
  defp i32_param_type(op, i) when op in @i_binary_ops and i in [0, 1], do: :i32
  defp i32_param_type(op, i) when op in @i_relative_ops and i in [0, 1], do: :i32
  defp i32_param_type(_, _), do: :error

  defp i64_param_type(op, param_index)
  defp i64_param_type(:const, 0), do: Elixir.Integer
  defp i64_param_type(op, 0) when op in @i64_load_ops, do: :i64
  defp i64_param_type(op, i) when op in @i64_store_ops and i in [0, 1], do: :i64
  defp i64_param_type(op, 0) when op in @i_trunc_ops, do: :f64
  defp i64_param_type(op, 0) when op in @i_unary_ops, do: :i64
  defp i64_param_type(op, 0) when op in @i_test_ops, do: :i64
  defp i64_param_type(op, 0) when op in @i64_extend_ops, do: :i32
  defp i64_param_type(op, i) when op in @i_binary_ops and i in [0, 1], do: :i64
  defp i64_param_type(op, i) when op in @i_relative_ops and i in [0, 1], do: :i64
  defp i64_param_type(_, _), do: :error

  defp f32_param_type(op, param_index)
  defp f32_param_type(:const, 0), do: Elixir.Float
  defp f32_param_type(:convert_i32_s, 0), do: :i32
  defp f32_param_type(:convert_i32_u, 0), do: :i32
  defp f32_param_type(:demote_f64, 0), do: :f64
  defp f32_param_type(op, 0) when op in @f32_ops_1, do: :f32
  defp f32_param_type(op, i) when op in @f32_ops_2 and i in [0, 1], do: :f32
  defp f32_param_type(_, _), do: :error

  defp f64_param_type(op, param_index)
  defp f64_param_type(:const, 0), do: Elixir.Float
  defp f64_param_type(:convert_i32_s, 0), do: :i32
  defp f64_param_type(:convert_i32_u, 0), do: :i32
  defp f64_param_type(:convert_i64_s, 0), do: :i64
  defp f64_param_type(:convert_i64_u, 0), do: :i64
  defp f64_param_type(:promote_f32, 0), do: :f32
  defp f64_param_type(op, 0) when op in @f64_ops_1, do: :f64
  defp f64_param_type(op, i) when op in @f64_ops_2 and i in [0, 1], do: :f64
  defp f64_param_type(_, _), do: :error

  def i32_param_type!(op, param_index) do
    case i32_param_type(op, param_index) do
      :error ->
        raise ArgumentError,
              "WebAssembly instruction i32.#{op}/#{i32_arity(op)} does not accept a #{nth(param_index)} argument."

      type ->
        type
    end
  end

  def i64_param_type!(op, param_index) do
    case i64_param_type(op, param_index) do
      :error ->
        raise ArgumentError,
              "WebAssembly instruction i64.#{op}/#{i64_arity(op)} does not accept a #{nth(param_index)} argument."

      type ->
        type
    end
  end

  def f32_param_type!(op, param_index) do
    case f32_param_type(op, param_index) do
      :error ->
        raise ArgumentError,
              "WebAssembly instruction f32.#{op}/#{f32_arity(op)} does not accept a #{nth(param_index)} argument."

      type ->
        type
    end
  end

  def f64_param_type!(op, param_index) do
    case f64_param_type(op, param_index) do
      :error ->
        raise ArgumentError,
              "WebAssembly instruction f64.#{op}/#{f64_arity(op)} does not accept a #{nth(param_index)} argument."

      type ->
        type
    end
  end

  def param_type!(:i32, op, param_index), do: i32_param_type!(op, param_index)
  def param_type!(:i64, op, param_index), do: i64_param_type!(op, param_index)
  def param_type!(:f32, op, param_index), do: f32_param_type!(op, param_index)
  def param_type!(:f64, op, param_index), do: f64_param_type!(op, param_index)

  defp nth(0), do: "1st"
  defp nth(1), do: "2nd"
  defp nth(2), do: "3rd"
  defp nth(n), do: "#{n + 1}th"
end
