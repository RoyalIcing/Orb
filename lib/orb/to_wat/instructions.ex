defmodule Orb.ToWat.Instructions do
  alias require Orb.Ops

  def do_wat(instruction), do: do_wat(instruction, "")

  def do_wat(:nop, indent), do: [indent, "nop"]
  def do_wat(:pop, _indent), do: []
  def do_wat(:drop, indent), do: [indent, "drop"]

  def do_wat(:select, indent), do: [indent, "select"]

  def do_wat(:return, indent), do: [indent, "return"]
  def do_wat({:return, value}, indent), do: [indent, "(return ", do_wat(value), ?)]

  def do_wat(:unreachable, indent), do: [indent, "unreachable"]

  def do_wat({:export, name}, indent), do: [indent, ~S/(export "/, to_string(name), ~S/")/]

  def do_wat({:result, value}, _indent), do: ["(result ", do_type(value), ")"]

  def do_wat({:i32_const, value}, indent), do: "#{indent}(i32.const #{value})"
  def do_wat({:i32_const_string, value, _string}, indent), do: "#{indent}(i32.const #{value})"
  def do_wat({:global_get, identifier}, indent), do: "#{indent}(global.get $#{identifier})"
  def do_wat({:global_set, identifier}, indent), do: "#{indent}(global.set $#{identifier})"
  def do_wat({:local, identifier, type}, indent), do: "#{indent}(local $#{identifier} #{type})"
  def do_wat({:local_get, identifier}, indent), do: "#{indent}(local.get $#{identifier})"
  def do_wat({:local_set, identifier}, indent), do: "#{indent}(local.set $#{identifier})"
  def do_wat({:local_tee, identifier}, indent), do: "#{indent}(local.tee $#{identifier})"
  def do_wat(value, indent) when is_integer(value), do: "#{indent}(i32.const #{value})"
  def do_wat(value, indent) when is_float(value), do: "#{indent}(f32.const #{value})"
  def do_wat({:i32, op}, indent) when op in Ops.i32(:all), do: "#{indent}(i32.#{op})"

  def do_wat({:i32, op, offset}, indent) when op in Ops.i32(:load) or op in Ops.i32(:store) do
    [indent, "(i32.", to_string(op), " ", do_wat(offset), ?)]
  end

  def do_wat({:i32, op, offset, value}, indent) when op in Ops.i32(:store) do
    [indent, "(i32.", to_string(op), " ", do_wat(offset), " ", do_wat(value), ?)]
  end

  def do_wat({:i32, op, a}, indent) when op in Ops.i32(1) do
    [indent, "(i32.", to_string(op), " ", do_wat(a), ?)]
  end

  def do_wat({:i32, op, {a, b}}, indent) when op in Ops.i32(2) do
    [indent, "(i32.", to_string(op), " ", do_wat(a), " ", do_wat(b), ?)]
  end

  def do_wat({:f32, op, a}, indent) when op in Ops.f32(1) do
    [indent, "(f32.", to_string(op), " ", do_wat(a), ?)]
  end

  def do_wat({:f32, op, {a, b}}, indent) when op in Ops.f32(2) do
    [indent, "(f32.", to_string(op), " ", do_wat(a), " ", do_wat(b), ?)]
  end

  def do_wat({:call, f, args}, indent) do
    [
      indent,
      "(call $",
      to_string(f),
      for(arg <- args, do: [" ", do_wat(arg)]),
      ")"
    ]
  end

  def do_wat({:br, identifier}, indent), do: [indent, "br $", to_string(identifier)]

  def do_wat({:br_if, identifier, condition}, indent),
    do: [indent, do_wat(condition), "\n", indent, "br_if $", to_string(identifier)]

  def do_wat({:br_if, identifier}, indent),
    do: [indent, "br_if $", to_string(identifier)]

  # def do_wat({:raw_wat, source}, indent), do: "#{indent}#{source}"
  def do_wat({:raw_wat, source}, indent) do
    lines = String.split(source, "\n")

    Enum.intersperse(
      for line <- lines do
        [indent, line]
      end,
      "\n"
    )
  end

  def do_wat(%struct{} = value, indent) do
    # Protocol.assert_impl!(struct, Orb.ToWat)

    Orb.ToWat.to_wat(value, indent)
  end

  defp do_type(type) do
    case type do
      type when type in [:i32, :i32_u8] ->
        "i32"

      :f32 ->
        "f32"

      tuple when is_tuple(tuple) ->
        tuple |> Tuple.to_list() |> Enum.map(&do_type/1) |> Enum.join(" ")

      type ->
        #         Code.ensure_loaded!(type)
        #
        #         unless function_exported?(type, :wasm_type, 0) do
        #           raise "Type #{type} must implement wasm_type/0."
        #         end

        type.wasm_type() |> to_string()
    end
  end
end
