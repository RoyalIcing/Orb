defmodule Orb.ToWat.Instructions do
  @moduledoc false

  def do_wat(instruction), do: do_wat(instruction, "")

  def do_wat(list, indent) when is_list(list) do
    Enum.map(list, &do_wat(&1, indent)) |> Enum.intersperse("\n")
    # Enum.map(list, &do_wat(&1, indent))
  end

  def do_wat(:nop, indent), do: [indent, "nop"]
  def do_wat(:pop, _indent), do: []
  def do_wat(:drop, indent), do: [indent, "drop"]

  def do_wat(:select, indent), do: [indent, "select"]

  def do_wat(:return, indent), do: [indent, "return"]
  def do_wat({:return, value}, indent), do: [indent, "(return ", do_wat(value), ?)]

  def do_wat(:unreachable, indent), do: [indent, "unreachable"]

  def do_wat({:export, name}, indent), do: [indent, ~S/(export "/, to_string(name), ~S/")/]

  def do_wat({:i32_const, value}, indent), do: "#{indent}(i32.const #{value})"
  def do_wat({:i32_const_string, value, _string}, indent), do: "#{indent}(i32.const #{value})"
  def do_wat({:f32_const, value}, indent), do: "#{indent}(f32.const #{value})"
  def do_wat({:global_get, identifier}, indent), do: "#{indent}(global.get $#{identifier})"
  def do_wat({:global_set, identifier}, indent), do: "#{indent}(global.set $#{identifier})"
  def do_wat({:local, identifier, type}, indent), do: "#{indent}(local $#{identifier} #{type})"
  def do_wat({:local_get, identifier}, indent), do: "#{indent}(local.get $#{identifier})"
  def do_wat({:local_set, identifier}, indent), do: "#{indent}(local.set $#{identifier})"
  def do_wat({:local_tee, identifier}, indent), do: "#{indent}(local.tee $#{identifier})"
  # TODO: how do we support 64-bit integers?
  def do_wat(value, indent) when is_integer(value), do: "#{indent}(i32.const #{value})"
  # TODO: how do we support 64-bit floats?
  # Note that Rust defaults to 64-bit floats: https://doc.rust-lang.org/book/ch03-02-data-types.html
  # “The default type is f64 because on modern CPUs, it’s roughly the same speed as f32 but is capable of more precision.”
  # So should our default be 64-bit too?
  def do_wat(value, indent) when is_float(value), do: "#{indent}(f32.const #{value})"

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

  def do_wat(%_struct{} = value, indent) do
    # Protocol.assert_impl!(struct, Orb.ToWat)

    Orb.ToWat.to_wat(value, indent)
  end
end
